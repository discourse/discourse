import liveLog from "discourse/plugins/live/discourse/lib/live/logger";

const TIMESLICE_MS = 1000;
const AUDIO_BITS_PER_SECOND = 128_000;
const VIDEO_BITS_PER_SECOND = 2_500_000;
const STORAGE_DIRECTORY = "live-local-recordings";
const STALE_AFTER_MS = 60 * 60 * 1000;

// MP4 first: MediaRecorder's WebM output has no duration or cues, so most
// players can't seek it.
const VIDEO_MIME_TYPES = [
  "video/mp4;codecs=avc1,opus",
  "video/mp4;codecs=avc1,mp4a.40.2",
  "video/webm;codecs=vp9,opus",
  "video/webm;codecs=vp8,opus",
  "video/mp4",
  "video/webm",
];

const AUDIO_MIME_TYPES = [
  "audio/mp4;codecs=opus",
  "audio/mp4;codecs=mp4a.40.2",
  "audio/webm;codecs=opus",
  "audio/ogg;codecs=opus",
  "audio/mp4",
  "audio/webm",
];

export function localRecordingSupported() {
  return (
    typeof window.MediaRecorder === "function" &&
    typeof window.AudioContext === "function"
  );
}

export function pickMimeType(
  withVideo,
  isTypeSupported = (type) => window.MediaRecorder.isTypeSupported(type)
) {
  return (withVideo ? VIDEO_MIME_TYPES : AUDIO_MIME_TYPES).find((type) =>
    isTypeSupported(type)
  );
}

export function recordingFilename(prefix, mimeType, date = new Date()) {
  const pad = (value) => String(value).padStart(2, "0");
  const stamp = [
    date.getFullYear(),
    pad(date.getMonth() + 1),
    pad(date.getDate()),
    `${pad(date.getHours())}${pad(date.getMinutes())}`,
  ].join("-");
  return `${prefix}-${stamp}.${fileExtension(mimeType)}`;
}

function fileExtension(mimeType = "") {
  const [type] = mimeType.split(";");
  switch (type) {
    case "video/mp4":
      return "mp4";
    case "audio/mp4":
      return "m4a";
    case "audio/ogg":
      return "ogg";
    default:
      return "webm";
  }
}

// Must be called synchronously from a click handler: Firefox only allows
// getDisplayMedia during the event dispatch itself.
export function requestTabCapture() {
  return navigator.mediaDevices.getDisplayMedia({
    video: { frameRate: 30 },
    audio: false,
    preferCurrentTab: true,
    selfBrowserSurface: "include",
    surfaceSwitching: "exclude",
  });
}

// Tab audio leaves out the recorder's own microphone and isn't available
// outside Chromium, so the soundtrack is mixed from the call's streams.
class AudioMixer {
  #context;
  #destination;
  #sources = new Map();

  constructor(context) {
    this.#context = context;
    this.#destination = context.createMediaStreamDestination();
  }

  get track() {
    return this.#destination.stream.getAudioTracks()[0];
  }

  sync(tracks) {
    const wanted = new Map(
      tracks
        .filter((track) => track?.readyState === "live")
        .map((track) => [track.id, track])
    );

    for (const [id, node] of this.#sources) {
      if (!wanted.has(id)) {
        node.disconnect();
        this.#sources.delete(id);
      }
    }

    for (const [id, track] of wanted) {
      if (!this.#sources.has(id)) {
        // One stream per track: a source node only reads a stream's first
        // audio track.
        const node = this.#context.createMediaStreamSource(
          new MediaStream([track])
        );
        node.connect(this.#destination);
        this.#sources.set(id, node);
      }
    }
  }

  destroy() {
    this.#sources.forEach((node) => node.disconnect());
    this.#sources.clear();
  }
}

// Chunks go to the origin-private file system when available so a long
// recording doesn't live in memory; otherwise they're kept in memory.
async function openSink(name) {
  try {
    const root = await navigator.storage.getDirectory();
    const directory = await root.getDirectoryHandle(STORAGE_DIRECTORY, {
      create: true,
    });
    await removeStaleFiles(directory);
    const handle = await directory.getFileHandle(name, { create: true });
    const writable = await handle.createWritable();
    return new FileSink(handle, writable);
  } catch {
    return new MemorySink();
  }
}

// A saved recording's download reads its file lazily, so recent files are
// left alone; anything older was saved long ago or lost with its tab.
async function removeStaleFiles(directory) {
  const cutoff = Date.now() - STALE_AFTER_MS;
  for await (const handle of directory.values()) {
    try {
      const file = await handle.getFile();
      if (file.lastModified < cutoff) {
        await directory.removeEntry(handle.name);
      }
    } catch {
      // Still open in another tab's recording.
    }
  }
}

class FileSink {
  #handle;
  #writable;
  #queue = Promise.resolve();
  #discarded = false;

  constructor(handle, writable) {
    this.#handle = handle;
    this.#writable = writable;
  }

  write(chunk) {
    if (this.#discarded) {
      return;
    }
    this.#queue = this.#queue.then(() => this.#writable.write(chunk));
    this.#queue.catch((error) =>
      liveLog.warn("[live] local recording write failed", error)
    );
  }

  async finish(type) {
    await this.#queue;
    await this.#writable.close();
    const file = await this.#handle.getFile();
    return new Blob([file], { type });
  }

  discard() {
    this.#discarded = true;
    this.#writable.abort().catch(() => {});
  }
}

class MemorySink {
  #chunks = [];

  write(chunk) {
    this.#chunks.push(chunk);
  }

  async finish(type) {
    const blob = new Blob(this.#chunks, { type });
    this.#chunks = [];
    return blob;
  }

  discard() {
    this.#chunks = [];
  }
}

// Records a call to a file on this device: the given display capture (if
// any) as video, and every audio track passed to sync() mixed as the
// soundtrack.
export default class LocalRecorder {
  #context;
  #mixer;
  #displayStream;
  #recorder;
  #sink;
  #mimeType;
  #stopped;
  #onEnded;

  constructor({ displayStream = null, onEnded }) {
    this.#displayStream = displayStream;
    this.#onEnded = onEnded;
    this.#context = new AudioContext();
    this.#mixer = new AudioMixer(this.#context);

    // The browser's own "Stop sharing" control ends the recording too.
    displayStream
      ?.getVideoTracks()[0]
      ?.addEventListener("ended", () => this.#onEnded());
  }

  get hasVideo() {
    return !!this.#displayStream;
  }

  sync(tracks) {
    this.#mixer.sync(tracks);
  }

  async start(name) {
    await this.#context.resume();
    this.#mimeType = pickMimeType(this.hasVideo);
    this.#sink = await openSink(name);

    const stream = new MediaStream([
      ...(this.#displayStream?.getVideoTracks() || []),
      this.#mixer.track,
    ]);
    this.#recorder = new MediaRecorder(stream, {
      mimeType: this.#mimeType,
      audioBitsPerSecond: AUDIO_BITS_PER_SECOND,
      videoBitsPerSecond: this.hasVideo ? VIDEO_BITS_PER_SECOND : undefined,
    });
    this.#stopped = new Promise((resolve) => {
      this.#recorder.addEventListener("stop", resolve, { once: true });
    });
    this.#recorder.addEventListener("dataavailable", (event) => {
      if (event.data.size > 0) {
        this.#sink.write(event.data);
      }
    });
    this.#recorder.addEventListener("error", () => this.#onEnded());
    this.#recorder.start(TIMESLICE_MS);
  }

  async stop() {
    try {
      if (this.#recorder && this.#recorder.state !== "inactive") {
        this.#recorder.stop();
      }
      await this.#stopped;
      return await this.#sink.finish(
        this.#recorder.mimeType || this.#mimeType || ""
      );
    } finally {
      this.#release();
    }
  }

  discard() {
    if (this.#recorder && this.#recorder.state !== "inactive") {
      this.#recorder.stop();
    }
    this.#sink?.discard();
    this.#release();
  }

  #release() {
    this.#displayStream?.getTracks().forEach((track) => track.stop());
    this.#mixer.destroy();
    this.#context.close().catch(() => {});
  }
}
