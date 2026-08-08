---
name: anki
description: Convert technical-reading notes into precise, deduplicated Anki cards and sync them through AnkiConnect. Use when the user provides a Markdown/text note, asks to turn book notes or study questions into Anki flashcards, wants to check or create the book's deck.
---

# Technical Notes to Anki

Convert a supplied note into a small set of testable cards, then use `scripts/anki_sync.py` to inspect or update the user's Anki collection through AnkiConnect. The default endpoint is set automatically to `ANKI_CONNECT_URL=http://anki:8765` automatically. Use `--url` to override either default.

## Workflow

1. Read the entire note. Determine the book/deck name, in this order: YAML `book`, YAML `deck`, the first H1, then the filename. Strip generic suffixes such as `notes`, `chapter`, and `reading notes`. If the result is ambiguous, ask before syncing.
2. Extract only questions the note can answer. Turn each into one atomic recall question. Keep answers factual, concise, and fully grounded in the note. Do not invent facts, citations, or context. If notes don't provide answers, generate them yourself, make sure the generated answers are detailed and properly answer the card's question.
3. Build a JSON array. Every card requires `front` and `back`; include `tags`, `source`, and `extra` when supplied by the note. Use the note-derived book title as a tag, plus topic tags.
4. Save the card JSON to a temporary file and sync it immediately:

   ```sh
   python3 -B scripts/anki_sync.py sync --note path/to/note.md --cards /tmp/anki-cards.json
   ```

   Do not ask for approval. `sync` checks existing cards, omits exact/near duplicates, creates the derived deck when absent, then adds the remaining cards. Report created card IDs and skipped duplicates after the call.
5. Run `check` or `sync --dry-run` only when the user explicitly asks for a preview. On a sync failure, report the error and do not claim that cards were added.

The script uses Anki's `Basic` model by default and puts `extra` and `source` below the answer.

## Card standards

- Prefer direct recall: `Why does …?`, `What invariant …?`, `When should …?`
- One independently answerable concept per card. Split lists and multi-part questions.
- Do not turn headings, vague reflections, or unanswered questions into cards.
- Preserve the note's uncertainty. If the note does not establish an answer, omit the card.
- Keep the answer short enough to review; put elaboration in `extra`.
- Never send an entire copyrighted book when the user's own notes or short excerpts are enough.

## Card JSON

```json
[
  {
    "front": "Why do additional database indexes slow writes?",
    "back": "Each write must also maintain every affected index.",
    "extra": "This can include page changes and index rebalancing.",
    "tags": ["databases", "indexes"],
    "source": "Chapter 4"
  }
]
```

Use `check` instead of `sync` only when the user wants a preview. `sync --dry-run` is equivalent.
