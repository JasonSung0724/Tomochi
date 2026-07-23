# Changelog

## 0.1.4

- Fixed sluggish button response: task cards no longer re-render on every
  timer tick, CLI detection no longer blocks the UI thread, and typing in
  the add-task field no longer redraws the whole list
- Design refresh: brand peach accent, rounded typography, gradient category
  icons, springy checkboxes, capsule timer with progress ring, refined AI
  chat bubbles
- Fixed AI provider picker rendering blank

## 0.1.3

- First-launch setup assistant: install-location check, notification
  permission, AI engine detection with one-click install command
- Reopen anytime via Tomochi → Setup Assistant…

## 0.1.2

- Markdown notes with drag-and-drop image attachments, live-synced with the
  AI workspace
- Task list redesigned as ticket-style cards (priority spine, category and
  due-date chips, hover quick actions)

## 0.1.1

- App icon (a very happy cat)
- Warn when running translocated (from DMG), where auto-update can't work

## 0.1.0

- Initial release
- Todo lists with categories, priorities, due dates, notes, and smart lists
- Pomodoro timer with menu-bar countdown, task linking, and daily stats
- AI assistant panel driven by local Claude Code (`claude -p`) or Codex
  (`codex exec`) CLI agents — no API keys required
- Self-learning AI memory (`memory/MEMORY.md`) for categorization habits
- Plain-file JSON/Markdown workspace with live reload
- Sparkle automatic updates
