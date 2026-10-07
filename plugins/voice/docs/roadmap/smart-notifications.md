# Smart Notifications

## Overview

Alert users when their frequent voice contacts join rooms. Uses co-presence
data from the analytics system (see `analytics.md`) to determine relationship
strength.

## Prerequisites

- Session tracking (analytics Phase 1) — `voice_sessions` table.
- Co-presence tracking (analytics Phase 2) — `voice_co_presences` table.

## "Your frequent contact joined a room"

**Trigger:** A user joins a room.

**Logic (in `RoomsController#join`, after recording the session):**

1. Query the joining user's top contacts from `voice_co_presences`
   (cached — see below).
2. For each top contact who is currently online (Discourse presence) but NOT
   in any voice room:
   - Check if the room the user just joined is one the contact frequents
     (from `voice_sessions` aggregation, also cached).
   - If both conditions met (strong relationship + familiar room), send a
     notification.

**Notification content:**
> "Alice joined Watercooler — you two have chatted 12 times this month"

**Delivery:** Discourse MessageBus push to the contact's browser → rendered as
a toast notification with a "Join" action button.

## Caching strategy

Computing top contacts and frequent rooms on every join would be expensive.

- **Top contacts per user:** Cache in Redis as a sorted set
  `voice:contacts:{user_id}` with score = aggregated `total_seconds` over
  the last 30 days. Refresh every hour via a scheduled job, or invalidate
  when `UpdateCoPresence` runs.
- **Frequent rooms per user:** Cache as `voice:frequent_rooms:{user_id}`.
  Refresh daily or on session close.
- **Notification cooldown:** Don't notify the same user about the same contact
  more than once per hour. Track in Redis:
  `voice:notified:{user_id}:{contact_id}` with 1h TTL.

## Thresholds

Not every co-presence should trigger notifications. Minimum thresholds:

- **Minimum co-presence time:** 30 minutes total within the lookback window
  (avoids noise from one-time encounters).
- **Minimum sessions:** 3 within the lookback window (avoids a single long
  session skewing results).
- **Recency lookback window:** 30 days (only co-presence rows with
  `date >= today - 30 days` are considered — stale relationships naturally
  drop out).
- **Room familiarity:** Contact has visited the room at least twice in the
  last 30 days (don't notify about unfamiliar rooms).

All thresholds configurable via site settings.

## Site settings

```yaml
voice_smart_notifications_enabled:
  default: true

voice_co_presence_min_seconds:
  default: 1800
  description: "Minimum co-presence time (seconds) before a relationship is considered for notifications"

voice_co_presence_min_sessions:
  default: 3

voice_smart_notification_cooldown_minutes:
  default: 60
  min: 10
  max: 1440
```

## User preferences

Users can control notification behavior from their Discourse notification
preferences (or a Voice-specific section):

- **Enable/disable** smart room notifications (default: enabled).
- **Quiet hours** — respect Discourse's existing Do Not Disturb setting.

No per-contact granularity in the first version — either on or off globally.

## Implementation plan

1. Implement notification logic in room join flow.
2. Add Redis caching for contacts and frequent rooms.
3. Add notification cooldown.
4. Add user preference toggle.
5. Frontend toast with "Join" action button.

## Privacy considerations

- Smart notifications respect Discourse's existing block/ignore system — if
  user A has blocked user B, no notifications are sent in either direction.
- Co-presence data is symmetric — if Alice can see Bob as a top contact, Bob
  can see Alice. There is no way to silently track someone.
