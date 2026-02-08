#!/usr/bin/env node

import { spawn, execSync } from "node:child_process";
import puppeteer from "puppeteer-core";
import { existsSync } from "node:fs";
import { platform, homedir } from "node:os";

const useProfile = process.argv[2] === "--profile";

if (process.argv[2] && process.argv[2] !== "--profile") {
	console.log("Usage: browser-start.js [--profile]");
	console.log("\nOptions:");
	console.log("  --profile  Copy your default Chrome profile (cookies, logins)");
	process.exit(1);
}

const SCRAPING_DIR = `${process.env.HOME}/.cache/browser-tools`;

// Check if already running on :9222
try {
	const browser = await puppeteer.connect({
		browserURL: "http://localhost:9222",
		defaultViewport: null,
	});
	await browser.disconnect();
	console.log("✓ Chrome already running on :9222");
	process.exit(0);
} catch {}

// Find Chrome executable (Linux first, then WSL, no macOS)
function findChrome() {
	// Check environment variable override first
	if (process.env.CHROME_PATH) {
		if (existsSync(process.env.CHROME_PATH)) {
			return process.env.CHROME_PATH;
		}
	}

	// Linux paths (search first)
	const linuxPaths = [
		"/usr/bin/google-chrome",
		"/usr/bin/google-chrome-stable",
		"/usr/bin/chromium",
		"/usr/bin/chromium-browser",
		"/snap/bin/chromium",
		"/usr/local/bin/google-chrome",
		"/usr/local/bin/chromium",
		"/opt/google/chrome/google-chrome",
		"/opt/google/chrome/chrome",
		"/opt/chromium.org/chromium/chrome",
	];

	for (const path of linuxPaths) {
		if (existsSync(path)) {
			return path;
		}
	}

	// Windows WSL paths
	const wslPaths = [
		"/mnt/c/Program Files/Google/Chrome/Application/chrome.exe",
		"/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe",
		"/mnt/c/Users/${process.env.USER}/AppData/Local/Google/Chrome/Application/chrome.exe",
	];

	for (const path of wslPaths) {
		const expandedPath = path.replace("${process.env.USER}", process.env.USER || "");
		if (existsSync(expandedPath)) {
			return expandedPath;
		}
	}

	// Fallback: try to find with 'which' command
	try {
		const chromePath = execSync("which google-chrome || which chromium || which chromium-browser", {
			encoding: "utf8",
			stdio: ["pipe", "pipe", "ignore"],
		}).trim();
		if (chromePath) return chromePath;
	} catch {}

	throw new Error("Chrome not found. Install Chrome/Chromium or set CHROME_PATH environment variable.");
}

let chromePath;
try {
	chromePath = findChrome();
	console.log(`Found Chrome at: ${chromePath}`);
} catch (e) {
	console.error("✗ " + e.message);
	process.exit(1);
}

// Setup profile directory
execSync(`mkdir -p "${SCRAPING_DIR}"`, { stdio: "ignore" });

// Remove SingletonLock to allow new instance
try {
	execSync(`rm -f "${SCRAPING_DIR}/SingletonLock" "${SCRAPING_DIR}/SingletonSocket" "${SCRAPING_DIR}/SingletonCookie"`, { stdio: "ignore" });
} catch {}

if (useProfile) {
	console.log("Syncing profile...");
	// Try common Linux profile locations
	const profilePaths = [
		`${homedir()}/.config/google-chrome`,
		`${homedir()}/.config/chromium`,
		`${homedir()}/.var/app/com.google.Chrome/config/google-chrome`, // Flatpak
	];
	
	let synced = false;
	for (const profilePath of profilePaths) {
		if (existsSync(profilePath)) {
			try {
				execSync(
					`rsync -a --delete \
						--exclude='SingletonLock' \
						--exclude='SingletonSocket' \
						--exclude='SingletonCookie' \
						--exclude='*/Sessions/*' \
						--exclude='*/Current Session' \
						--exclude='*/Current Tabs' \
						--exclude='*/Last Session' \
						--exclude='*/Last Tabs' \
						"${profilePath}/" "${SCRAPING_DIR}/"`,
					{ stdio: "pipe" },
				);
				console.log(`Synced profile from: ${profilePath}`);
				synced = true;
				break;
			} catch {}
		}
	}
	
	if (!synced) {
		console.log("Warning: No existing Chrome profile found to sync. Using fresh profile.");
	}
}

// Start Chrome with flags to force new instance
spawn(
	chromePath,
	[
		"--remote-debugging-port=9222",
		`--user-data-dir=${SCRAPING_DIR}`,
		"--no-first-run",
		"--no-default-browser-check",
	],
	{ detached: true, stdio: "ignore" },
).unref();

// Wait for Chrome to be ready
let connected = false;
for (let i = 0; i < 30; i++) {
	try {
		const browser = await puppeteer.connect({
			browserURL: "http://localhost:9222",
			defaultViewport: null,
		});
		await browser.disconnect();
		connected = true;
		break;
	} catch {
		await new Promise((r) => setTimeout(r, 500));
	}
}

if (!connected) {
	console.error("✗ Failed to connect to Chrome");
	process.exit(1);
}

console.log(`✓ Chrome started on :9222${useProfile ? " with your profile" : ""}`);
