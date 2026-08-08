#!/usr/bin/env python3
"""Check and sync structured technical-note cards through AnkiConnect."""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
import sys
from pathlib import Path
from typing import Any
from urllib.error import URLError
from urllib.request import Request, urlopen


ANKI_CONNECT_URL = os.environ.get("ANKI_CONNECT_URL", "http://127.0.0.1:8765")
GENERIC_TITLE_SUFFIX = re.compile(
    r"(?:\s*[-–—:]?\s*(?:notes?|reading notes?|chapter\s*\d+))+$", re.IGNORECASE
)
HTML_TAG = re.compile(r"<[^>]+>")
WORD = re.compile(r"[a-z0-9]+")


def anki(action: str, params: dict[str, Any], url: str) -> Any:
    payload = json.dumps({"action": action, "version": 6, "params": params}).encode()
    request = Request(url, data=payload, headers={"Content-Type": "application/json"})
    try:
        with urlopen(request, timeout=10) as response:
            body = json.loads(response.read().decode())
    except URLError as error:
        raise RuntimeError(
            "Cannot reach AnkiConnect. Open Anki, install/enable AnkiConnect, and confirm "
            f"that it listens on {url}."
        ) from error
    if body.get("error"):
        raise RuntimeError(f"AnkiConnect {action} failed: {body['error']}")
    return body.get("result")


def clean_text(value: str) -> str:
    value = html.unescape(HTML_TAG.sub(" ", value))
    return " ".join(WORD.findall(value.lower()))


def token_similarity(left: str, right: str) -> float:
    left_words, right_words = set(WORD.findall(left.lower())), set(WORD.findall(right.lower()))
    if not left_words or not right_words:
        return 0.0
    return len(left_words & right_words) / len(left_words | right_words)


def title_from_note(note_path: Path) -> str:
    text = note_path.read_text(encoding="utf-8")
    frontmatter = re.match(r"^---\s*\n(.*?)\n---\s*\n", text, re.DOTALL)
    if frontmatter:
        for key in ("book", "deck"):
            match = re.search(rf"^{key}:\s*[\"']?(.+?)[\"']?\s*$", frontmatter.group(1), re.MULTILINE | re.IGNORECASE)
            if match:
                return match.group(1).strip()
    heading = re.search(r"^#\s+(.+?)\s*$", text, re.MULTILINE)
    raw = heading.group(1) if heading else note_path.stem.replace("-", " ").replace("_", " ")
    title = GENERIC_TITLE_SUFFIX.sub("", raw).strip()
    if not title:
        raise ValueError("Could not derive a deck name from the note. Add `book:` or `deck:` frontmatter.")
    return title


def load_cards(cards_path: Path) -> list[dict[str, Any]]:
    data = json.loads(cards_path.read_text(encoding="utf-8"))
    if isinstance(data, dict):
        data = data.get("cards")
    if not isinstance(data, list) or not data:
        raise ValueError("Cards JSON must be a non-empty array, or an object with a non-empty `cards` array.")
    cards: list[dict[str, Any]] = []
    for position, raw in enumerate(data, start=1):
        if not isinstance(raw, dict) or not isinstance(raw.get("front"), str) or not isinstance(raw.get("back"), str):
            raise ValueError(f"Card {position} needs non-empty string `front` and `back` fields.")
        front, back = raw["front"].strip(), raw["back"].strip()
        if not front or not back:
            raise ValueError(f"Card {position} needs non-empty string `front` and `back` fields.")
        tags = raw.get("tags", [])
        if not isinstance(tags, list) or not all(isinstance(tag, str) and tag.strip() for tag in tags):
            raise ValueError(f"Card {position} `tags` must be an array of non-empty strings.")
        cards.append({
            "front": front,
            "back": back,
            "extra": str(raw.get("extra", "")).strip(),
            "source": str(raw.get("source", "")).strip(),
            "tags": [tag.strip() for tag in tags],
        })
    return cards


def existing_notes(deck: str, url: str) -> list[dict[str, Any]]:
    safe_deck = deck.replace('"', r'\"')
    ids = anki("findNotes", {"query": f'deck:"{safe_deck}"'}, url)
    return anki("notesInfo", {"notes": ids}, url) if ids else []


def existing_card_text(note: dict[str, Any]) -> tuple[str, str]:
    fields = note.get("fields", {})
    front = fields.get("Front", {}).get("value", "")
    back = fields.get("Back", {}).get("value", "")
    return clean_text(front), clean_text(back)


def compare_cards(cards: list[dict[str, Any]], notes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for card in cards:
        front, back = clean_text(card["front"]), clean_text(card["back"])
        match: dict[str, Any] | None = None
        for note in notes:
            known_front, known_back = existing_card_text(note)
            exact = front == known_front and back == known_back
            near = token_similarity(front, known_front) >= 0.86 and token_similarity(back, known_back) >= 0.75
            if exact or near:
                match = {"note_id": note["noteId"], "kind": "exact" if exact else "near", "front": note.get("fields", {}).get("Front", {}).get("value", "")}
                break
        results.append({"card": card, "duplicate": match})
    return results


def as_basic_note(deck: str, card: dict[str, Any]) -> dict[str, Any]:
    details = "".join(
        f"<br><br><b>{label}:</b> {html.escape(value)}" for label, value in (("Extra", card["extra"]), ("Source", card["source"])) if value
    )
    signature = hashlib.sha256((clean_text(card["front"]) + "\n" + clean_text(card["back"])).encode()).hexdigest()[:16]
    return {
        "deckName": deck,
        "modelName": "Basic",
        "fields": {"Front": card["front"], "Back": card["back"] + details + f"<!-- technical-notes-to-anki:{signature} -->"},
        "tags": card["tags"],
        "options": {"allowDuplicate": False},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check", "sync"))
    parser.add_argument("--note", required=True, type=Path, help="Source Markdown/text note")
    parser.add_argument("--cards", required=True, type=Path, help="Structured card JSON")
    parser.add_argument("--deck", help="Override the deck name derived from the note")
    parser.add_argument("--url", default=ANKI_CONNECT_URL, help="AnkiConnect URL")
    parser.add_argument("--dry-run", action="store_true", help="Inspect only; do not create a deck or cards")
    args = parser.parse_args()

    try:
        deck = args.deck or title_from_note(args.note)
        cards = load_cards(args.cards)
        decks = anki("deckNames", {}, args.url)
        deck_exists = deck in decks
        compared = compare_cards(cards, existing_notes(deck, args.url) if deck_exists else [])
        duplicates = [item for item in compared if item["duplicate"]]
        additions = [item["card"] for item in compared if not item["duplicate"]]
        report = {"deck": deck, "deck_exists": deck_exists, "proposed": len(cards), "duplicates": duplicates, "to_add": additions}
        if args.command == "sync" and not args.dry_run:
            if not deck_exists:
                anki("createDeck", {"deck": deck}, args.url)
                report["deck_created"] = True
            report["created_note_ids"] = anki("addNotes", {"notes": [as_basic_note(deck, card) for card in additions]}, args.url) if additions else []
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
