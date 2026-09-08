# Local fake participants for Voice

This developer-only harness opens several Playwright browser contexts, logs each one in as a bot user, injects fake camera/audio/screen-share media, and joins a Voice room. It is meant for local interactive WebRTC testing, not CI.

## Quick start

From the plugin checkout:

```bash
pnpm install
DISCOURSE_URL=http://localhost:4200 ROOM=watercooler BOT_COUNT=3 \
  pnpm voice:bots -- --headed --screenshots
```

By default the harness uses Discourse's development/test-only `/session/:username/become.json` login route. That means the named users must already exist and the target site must allow that route.

## Bot config

If `.local/voice-bots.json` exists, it is used instead of generated `voice_bot_N` usernames.

Create it from the example:

```bash
mkdir -p .local
cp docs/examples/voice-bots.example.json .local/voice-bots.json
```

Example:

```json
[
  {
    "username": "voice_bot_1",
    "label": "Alice fake camera",
    "color": "#2563eb",
    "accent": "#f97316"
  },
  {
    "username": "voice_bot_2",
    "label": "Bob fake camera",
    "color": "#16a34a",
    "accent": "#7c3aed"
  }
]
```

You can also pass JSON directly:

```bash
VOICE_BOTS_JSON='[{"username":"alice"},{"username":"bob"}]' \
  DISCOURSE_URL=http://localhost:4200 ROOM=watercooler pnpm voice:bots -- --headed
```

## Useful options

```bash
pnpm voice:bots -- --help
```

Common flags:

- `--headed`: show browser windows.
- `--screenshots`: write screenshots to `tmp/voice-bots/`.
- `--trace`: write Playwright trace zips to `tmp/voice-bots/`.
- `--record-video`: write Playwright videos to `tmp/voice-bots/`.
- `--screen-share-bot 1`: make the first bot start fake screen share.
- `--hold-ms 30000`: auto-close after 30 seconds; otherwise runs until Ctrl-C.
- `--no-camera`: join without immediately starting camera.

## Password login mode

For non-development sites, use password login with credentials in the ignored local file:

```json
[
  { "username": "voice_bot_1", "password": "local-only-password" },
  { "username": "voice_bot_2", "password": "local-only-password" }
]
```

Then run:

```bash
LOGIN_MODE=password DISCOURSE_URL=https://example.test ROOM=watercooler \
  pnpm voice:bots -- --headed
```

Do not commit real credentials.

## Notes

- The harness works unchanged against rooms routed through a LiveKit server: the plugin acquires media itself (through these same fakes) and hands the SDK finished tracks, so `livekit-client` never calls `getUserMedia`.
- Each bot uses a distinct canvas-backed camera stream with a visible label and animated frame marker.
- Audio is a very-low-gain oscillator so the browser sees a real audio track without audible noise.
- `getDisplayMedia` returns a separate fake screen-share canvas derived from the bot feed.
- Browser logs are echoed with the bot username prefix.
