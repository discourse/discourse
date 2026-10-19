#!/usr/bin/env node
/* eslint-disable no-console */

const DEFAULT_COLORS = [
  ["#2563eb", "#f97316"],
  ["#16a34a", "#7c3aed"],
  ["#dc2626", "#0891b2"],
  ["#9333ea", "#facc15"],
  ["#0f766e", "#e11d48"],
];

function parseArgs(argv) {
  const options = {
    baseUrl: process.env.DISCOURSE_URL || "http://localhost:4200",
    room: process.env.ROOM || "watercooler",
    botCount: Number(process.env.BOT_COUNT || 2),
    botsFile: process.env.VOICE_BOTS_FILE || ".local/voice-bots.json",
    headed: false,
    trace: false,
    screenshots: false,
    recordVideo: false,
    camera: true,
    screenShareBot: Number(process.env.SCREEN_SHARE_BOT || 0),
    holdMs: Number(process.env.HOLD_MS || 0),
    loginMode: process.env.LOGIN_MODE || "become",
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const next = () => argv[++index];

    switch (arg) {
      case "--":
        break;
      case "--url":
        options.baseUrl = next();
        break;
      case "--room":
        options.room = next();
        break;
      case "--bot-count":
        options.botCount = Number(next());
        break;
      case "--bots-file":
        options.botsFile = next();
        break;
      case "--headed":
        options.headed = true;
        break;
      case "--trace":
        options.trace = true;
        break;
      case "--screenshots":
        options.screenshots = true;
        break;
      case "--record-video":
        options.recordVideo = true;
        break;
      case "--no-camera":
        options.camera = false;
        break;
      case "--screen-share-bot":
        options.screenShareBot = Number(next());
        break;
      case "--hold-ms":
        options.holdMs = Number(next());
        break;
      case "--login-mode":
        options.loginMode = next();
        break;
      case "--help":
      case "-h":
        printHelp();
        process.exit(0);
      // eslint-disable-next-line no-fallthrough -- process.exit never falls through
      default:
        throw new Error(`Unknown option: ${arg}`);
    }
  }

  if (!options.baseUrl) {
    throw new Error("DISCOURSE_URL or --url is required");
  }

  if (!options.room) {
    throw new Error("ROOM or --room is required");
  }

  if (!Number.isInteger(options.botCount) || options.botCount < 1) {
    throw new Error("BOT_COUNT / --bot-count must be a positive integer");
  }

  return options;
}

function printHelp() {
  console.log(`Usage:
  DISCOURSE_URL=http://localhost:4200 ROOM=watercooler pnpm voice:bots -- --headed --bot-count 3

Options:
  --url <url>                 Base Discourse URL. Env: DISCOURSE_URL
  --room <slug>               Voice room slug. Env: ROOM
  --bot-count <n>             Number of generated bots if no bots file exists. Env: BOT_COUNT
  --bots-file <path>          JSON bot config. Default: .local/voice-bots.json
  --login-mode <mode>         become or password. Default: become
  --headed                    Show browser windows
  --trace                     Capture Playwright traces under tmp/voice-bots
  --screenshots               Capture screenshots under tmp/voice-bots
  --record-video              Record Playwright videos under tmp/voice-bots
  --no-camera                 Join without auto-enabling camera
  --screen-share-bot <n>      1-based bot index that should start screen share
  --hold-ms <ms>              Auto-close after this many ms; default holds until Ctrl-C
`);
}

async function fileExists(path) {
  const { access } = await import("node:fs/promises");
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

async function loadBots(options) {
  const { readFile } = await import("node:fs/promises");

  if (process.env.VOICE_BOTS_JSON) {
    return JSON.parse(process.env.VOICE_BOTS_JSON).slice(0, options.botCount);
  }

  if (options.botsFile && (await fileExists(options.botsFile))) {
    return JSON.parse(await readFile(options.botsFile, "utf8")).slice(
      0,
      options.botCount
    );
  }

  return Array.from({ length: options.botCount }, (_, index) => ({
    username: `voice_bot_${index + 1}`,
    name: `Voice Bot ${index + 1}`,
  }));
}

function feedFor(bot, index) {
  const [color, accent] = DEFAULT_COLORS[index % DEFAULT_COLORS.length];
  return {
    label: bot.label || bot.name || bot.username || `Voice Bot ${index + 1}`,
    width: bot.width || 640,
    height: bot.height || 360,
    color: bot.color || color,
    accent: bot.accent || accent,
  };
}

function fakeMediaInitScript({ feed }) {
  const mediaDevices = navigator.mediaDevices || {};
  Object.defineProperty(navigator, "mediaDevices", {
    configurable: true,
    value: mediaDevices,
  });

  const streams = [];

  function cleanupWhenTrackStops(track, cleanup) {
    let cleaned = false;
    const runCleanup = () => {
      if (cleaned) {
        return;
      }
      cleaned = true;
      cleanup();
    };
    const originalStop = track.stop.bind(track);
    track.stop = () => {
      runCleanup();
      originalStop();
    };
    track.addEventListener("ended", runCleanup, { once: true });
  }

  function createVideoStream(videoFeed) {
    const canvas = document.createElement("canvas");
    canvas.width = videoFeed.width;
    canvas.height = videoFeed.height;
    const context = canvas.getContext("2d");
    let frame = 0;

    const drawFrame = () => {
      frame += 1;
      const x = (frame * 17) % videoFeed.width;
      const y = videoFeed.height / 2 - 40;

      context.fillStyle = videoFeed.color;
      context.fillRect(0, 0, videoFeed.width, videoFeed.height);
      context.fillStyle = "rgba(255, 255, 255, 0.18)";
      context.fillRect(0, videoFeed.height - 96, videoFeed.width, 96);
      context.fillStyle = videoFeed.accent || "rgba(0, 0, 0, 0.35)";
      context.fillRect(x, y, 120, 80);
      context.fillStyle = "#fff";
      context.font = "32px sans-serif";
      context.fillText(videoFeed.label, 24, 48);
      context.font = "20px sans-serif";
      context.fillText(`frame ${frame}`, 24, videoFeed.height - 38);
    };

    drawFrame();
    const timer = window.setInterval(drawFrame, 100);
    const stream = canvas.captureStream(10);
    stream.getTracks().forEach((track) => {
      track.__voiceFakeMediaLabel = videoFeed.label;
      cleanupWhenTrackStops(track, () => window.clearInterval(timer));
    });
    streams.push(stream);
    return stream;
  }

  function createAudioStream() {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    const audioContext = new AudioContext();
    const oscillator = audioContext.createOscillator();
    const gain = audioContext.createGain();
    const destination = audioContext.createMediaStreamDestination();

    oscillator.frequency.value = 220;
    gain.gain.value = 0.0001;
    oscillator.connect(gain);
    gain.connect(destination);
    oscillator.start();

    destination.stream.getTracks().forEach((track) => {
      cleanupWhenTrackStops(track, () => {
        oscillator.stop();
        audioContext.close();
      });
    });

    streams.push(destination.stream);
    return destination.stream;
  }

  function addTracks(target, source) {
    source.getTracks().forEach((track) => target.addTrack(track));
  }

  mediaDevices.getUserMedia = async (constraints = {}) => {
    const stream = new MediaStream();

    if (constraints.audio) {
      addTracks(stream, createAudioStream());
    }

    if (constraints.video) {
      addTracks(stream, createVideoStream(feed));
    }

    return stream;
  };

  mediaDevices.getDisplayMedia = async () => {
    return createVideoStream({
      ...feed,
      label: `${feed.label} screen`,
      width: 1024,
      height: 576,
      color: feed.accent || feed.color,
      accent: "#111827",
    });
  };

  window.__voiceFakeBotMedia = { feed, streams };
}

async function login(page, bot, options) {
  if (options.loginMode === "become") {
    const becomeUrl = new URL(
      `/session/${encodeURIComponent(bot.username)}/become.json`,
      options.baseUrl
    );
    becomeUrl.searchParams.set("redirect", "false");
    await page.goto(becomeUrl.toString(), { waitUntil: "domcontentloaded" });
    return;
  }

  if (options.loginMode !== "password") {
    throw new Error(`Unsupported login mode: ${options.loginMode}`);
  }

  if (!bot.password) {
    throw new Error(
      `Bot ${bot.username} is missing a password for password login mode`
    );
  }

  await page.goto(new URL("/login", options.baseUrl).toString());
  await page.getByLabel(/email|username/i).fill(bot.username);
  await page.getByLabel(/password/i).fill(bot.password);
  await page.getByRole("button", { name: /log in|login/i }).click();
  await page.waitForLoadState("networkidle");
}

async function clickIfVisible(page, locator, label) {
  try {
    await locator.click({ timeout: 5000 });
    console.log(`  clicked ${label}`);
    return true;
  } catch (error) {
    console.warn(`  could not click ${label}: ${error.message}`);
    return false;
  }
}

async function runBot({ browser, bot, index, options, outputDir }) {
  const feed = feedFor(bot, index);
  const context = await browser.newContext({
    recordVideo: options.recordVideo ? { dir: outputDir } : undefined,
  });

  if (options.trace) {
    await context.tracing.start({ screenshots: true, snapshots: true });
  }

  await context.addInitScript(fakeMediaInitScript, { feed });

  const page = await context.newPage();
  page.on("console", (message) => {
    console.log(`[${bot.username}] ${message.type()}: ${message.text()}`);
  });
  page.on("pageerror", (error) => {
    console.error(`[${bot.username}] pageerror: ${error.message}`);
  });

  console.log(`[${bot.username}] logging in (${options.loginMode})`);
  await login(page, bot, options);

  const roomUrl = new URL(
    `/voice/r/${encodeURIComponent(options.room)}`,
    options.baseUrl
  ).toString();
  console.log(`[${bot.username}] opening ${roomUrl}`);
  await page.goto(roomUrl, { waitUntil: "domcontentloaded" });

  await clickIfVisible(
    page,
    page.getByRole("button", { name: /join/i }),
    "join"
  );

  if (options.camera) {
    await clickIfVisible(
      page,
      page.getByRole("button", { name: /camera/i }),
      "camera"
    );
  }

  if (options.screenShareBot === index + 1) {
    await clickIfVisible(
      page,
      page.getByRole("button", { name: /screen|share/i }),
      "screen share"
    );
  }

  if (options.screenshots) {
    await page.screenshot({
      path: `${outputDir}/${String(index + 1).padStart(2, "0")}-${bot.username}.png`,
      fullPage: true,
    });
  }

  return { context, page, bot, feed };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const { chromium } = await import("playwright").catch((error) => {
    throw new Error(
      `Could not load Playwright. Run pnpm install first, or execute from a checkout that has Playwright installed. Original error: ${error.message}`
    );
  });
  const { mkdir } = await import("node:fs/promises");

  const outputDir = "tmp/voice-bots";
  await mkdir(outputDir, { recursive: true });

  const bots = await loadBots(options);
  if (bots.length === 0) {
    throw new Error("No bots configured");
  }

  console.log(
    `Starting ${bots.length} Voice fake participant(s) against ${options.baseUrl}`
  );
  const browser = await chromium.launch({ headless: !options.headed });
  const sessions = [];

  try {
    for (let index = 0; index < bots.length; index += 1) {
      sessions.push(
        await runBot({ browser, bot: bots[index], index, options, outputDir })
      );
    }

    console.log("All bots joined. Press Ctrl-C to close.");
    if (options.holdMs > 0) {
      await new Promise((resolve) => setTimeout(resolve, options.holdMs));
    } else {
      await new Promise(() => {});
    }
  } finally {
    for (let index = 0; index < sessions.length; index += 1) {
      const session = sessions[index];
      if (options.trace) {
        await session.context.tracing.stop({
          path: `${outputDir}/${String(index + 1).padStart(2, "0")}-${session.bot.username}.zip`,
        });
      }
      await session.context.close();
    }
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
