# Changelog

## 0.1.7

- Sidebar rebuilt as custom rows: every item is now reliably clickable, with
  a consistent colored icon-tile language, hover feedback, and clear selection
- Calendar: upcoming-7-days rail under the month picker, day navigation
  (‹ Today ›), prominent New Event button
- Notes: content preview line in the list, accent selection, roomier editor
- Assistant panel: cat avatar, example prompts, refined input field

## 0.1.6

- Calendar tab: month picker plus a day agenda showing calendar events and
  tasks due that day; create events in-app (syncs to Google via macOS
  Calendar accounts)
- AI calendar bridge: the schedule is mirrored to data/calendar.json for the
  AI to read, and events the AI writes to data/calendar-outbox.json become
  real calendar entries
- Calendar access is requested only when you open the Calendar tab

## 0.1.5

- Fixed broken window layout (Notes pane collapsing to the bottom, skewed
  content, unclickable sidebar) caused by HSplitView inside the split view
- Global search across tasks and note contents (toolbar search field)
- New-category field now cancels when it loses focus instead of sticking
- AI now organizes long braindumps by itself: actionable items → todos,
  reference knowledge → notes, habits → memory, with a recap of what went
  where

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
