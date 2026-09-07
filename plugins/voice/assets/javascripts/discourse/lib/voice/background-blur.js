// Camera background blur.
//
// Runs the raw camera stream through MediaPipe selfie segmentation and
// composites each frame on a canvas — blurred frame behind, sharp person
// cutout in front — then captures the canvas as the outgoing stream.
// Mirrors the NoiseSuppressionManager contract: setup(raw stream) returns
// the processed stream; the caller keeps ownership of the raw stream.

import { voiceAssetUrl } from "./voice-assets";

const ENABLED_KEY = "voice_video_blur_enabled";
const AMOUNT_KEY = "voice_video_blur_amount";

// Bounds the wait for the hidden <video> to start playing. Without it, a
// raw stream whose track ends mid-setup could hang the caller forever.
const PLAY_TIMEOUT_MS = 10000;

export const DEFAULT_BLUR_AMOUNT = 50;

// Blur radius in px at 720p with the slider at 100; scales with the actual
// frame height so the effect looks the same at any capture resolution.
const MAX_BLUR_PX = 40;

// Feather the upscaled mask so the person edge blends instead of cutting.
const MASK_FEATHER_PX = 3;

// The wasm runtime and model stay resident after first use so re-enabling
// blur is instant; every manager instance shares one segmenter.
let segmenterPromise = null;

// VIDEO-mode segmentation requires strictly increasing timestamps across
// all users of the shared segmenter.
let lastTimestamp = 0;

function mediapipeBase() {
  return voiceAssetUrl("mediapipe");
}

async function loadSegmenter() {
  segmenterPromise ||= (async () => {
    const base = mediapipeBase();
    const vision = await import(/* @vite-ignore */ `${base}/vision_bundle.js`);
    const fileset = await vision.FilesetResolver.forVisionTasks(`${base}/wasm`);
    return await vision.ImageSegmenter.createFromOptions(fileset, {
      baseOptions: {
        modelAssetPath: `${base}/selfie_segmenter.tflite`,
        delegate: "GPU",
      },
      runningMode: "VIDEO",
      outputConfidenceMasks: true,
      outputCategoryMask: false,
    });
  })();

  try {
    return await segmenterPromise;
  } catch (error) {
    // Allow a retry after a transient failure (e.g. offline asset fetch).
    segmenterPromise = null;
    throw error;
  }
}

export default class BackgroundBlurManager {
  static isSupported() {
    return (
      typeof HTMLCanvasElement !== "undefined" &&
      typeof HTMLCanvasElement.prototype.captureStream === "function" &&
      typeof WebAssembly !== "undefined"
    );
  }

  static isPreferred() {
    try {
      return localStorage.getItem(ENABLED_KEY) === "1";
    } catch {
      return false;
    }
  }

  static setPreference(enabled) {
    try {
      if (enabled) {
        localStorage.setItem(ENABLED_KEY, "1");
      } else {
        localStorage.removeItem(ENABLED_KEY);
      }
    } catch {
      // ignore storage errors
    }
  }

  static storedAmount() {
    try {
      const value = parseInt(localStorage.getItem(AMOUNT_KEY), 10);
      if (Number.isFinite(value)) {
        return Math.max(0, Math.min(100, value));
      }
    } catch {
      // ignore storage errors
    }
    return DEFAULT_BLUR_AMOUNT;
  }

  static storeAmount(value) {
    try {
      localStorage.setItem(AMOUNT_KEY, String(value));
    } catch {
      // ignore storage errors
    }
  }

  #video = null;
  #outputCanvas = null;
  #outputCtx = null;
  #personCanvas = null;
  #personCtx = null;
  #maskCanvas = null;
  #maskCtx = null;
  #maskImageData = null;
  #segmenter = null;
  #stream = null;
  #running = false;
  #frameCallbackId = null;
  #timerId = null;
  #amount = DEFAULT_BLUR_AMOUNT;
  #onVisibilityChange = () => this.#rescheduleRender();

  get active() {
    return this.#running;
  }

  get stream() {
    return this.#stream;
  }

  setAmount(value) {
    this.#amount = Math.max(0, Math.min(100, value));
  }

  async setup(rawStream, amount = BackgroundBlurManager.storedAmount()) {
    this.#amount = Math.max(0, Math.min(100, amount));

    const rawTrack = rawStream.getVideoTracks()[0];
    if (!rawTrack || rawTrack.readyState !== "live") {
      throw new Error("raw video stream is not live");
    }

    this.#segmenter = await loadSegmenter();

    const video = document.createElement("video");
    video.muted = true;
    video.playsInline = true;
    video.srcObject = rawStream;

    let playTimer;
    try {
      await Promise.race([
        video.play(),
        new Promise((_, reject) => {
          playTimer = setTimeout(
            () => reject(new Error("camera stream failed to start")),
            PLAY_TIMEOUT_MS
          );
        }),
      ]);
    } finally {
      clearTimeout(playTimer);
    }

    this.#video = video;
    this.#outputCanvas = document.createElement("canvas");
    this.#outputCtx = this.#outputCanvas.getContext("2d");
    this.#personCanvas = document.createElement("canvas");
    this.#personCtx = this.#personCanvas.getContext("2d");
    this.#maskCanvas = document.createElement("canvas");
    this.#maskCtx = this.#maskCanvas.getContext("2d");

    this.#running = true;
    document.addEventListener("visibilitychange", this.#onVisibilityChange);

    // Paint the first frame before capturing so the track never starts black.
    this.#renderFrame();
    this.#scheduleRender();

    this.#stream = this.#outputCanvas.captureStream();
    return this.#stream;
  }

  teardown() {
    this.#running = false;
    document.removeEventListener("visibilitychange", this.#onVisibilityChange);
    this.#cancelScheduledRender();

    this.#stream?.getTracks().forEach((track) => track.stop());
    this.#stream = null;

    if (this.#video) {
      this.#video.srcObject = null;
      this.#video = null;
    }

    // The shared segmenter stays loaded for the next enable.
    this.#segmenter = null;
    this.#outputCanvas = null;
    this.#outputCtx = null;
    this.#personCanvas = null;
    this.#personCtx = null;
    this.#maskCanvas = null;
    this.#maskCtx = null;
    this.#maskImageData = null;
  }

  #scheduleRender() {
    if (!this.#running) {
      return;
    }

    // rVFC/rAF stall in hidden tabs, which would freeze the outgoing video
    // for everyone watching; fall back to a timer (browser-clamped, but the
    // stream keeps moving).
    if (document.hidden || !this.#video.requestVideoFrameCallback) {
      const delay = document.hidden ? 100 : 1000 / 30;
      this.#timerId = setTimeout(() => this.#render(), delay);
    } else {
      this.#frameCallbackId = this.#video.requestVideoFrameCallback(() =>
        this.#render()
      );
    }
  }

  #cancelScheduledRender() {
    if (this.#frameCallbackId && this.#video?.cancelVideoFrameCallback) {
      this.#video.cancelVideoFrameCallback(this.#frameCallbackId);
    }
    this.#frameCallbackId = null;

    if (this.#timerId) {
      clearTimeout(this.#timerId);
      this.#timerId = null;
    }
  }

  #rescheduleRender() {
    if (!this.#running) {
      return;
    }
    this.#cancelScheduledRender();
    this.#scheduleRender();
  }

  #render() {
    if (!this.#running) {
      return;
    }

    try {
      this.#renderFrame();
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn("[voice] background blur frame failed", error);
    }

    this.#scheduleRender();
  }

  #renderFrame() {
    const video = this.#video;
    const width = video.videoWidth;
    const height = video.videoHeight;

    if (!width || !height) {
      return;
    }

    if (
      this.#outputCanvas.width !== width ||
      this.#outputCanvas.height !== height
    ) {
      this.#outputCanvas.width = width;
      this.#outputCanvas.height = height;
      this.#personCanvas.width = width;
      this.#personCanvas.height = height;
    }

    const timestamp = Math.max(performance.now(), lastTimestamp + 1);
    lastTimestamp = timestamp;

    // Callback form: the mask is only valid inside the callback, which runs
    // synchronously, so the mask canvas is current for the composite below.
    this.#segmenter.segmentForVideo(video, timestamp, (result) =>
      this.#paintMask(result)
    );

    // Person cutout: upscaled + feathered mask, then keep only the video
    // pixels where the mask is opaque.
    const personCtx = this.#personCtx;
    personCtx.clearRect(0, 0, width, height);
    personCtx.filter = `blur(${MASK_FEATHER_PX}px)`;
    personCtx.drawImage(this.#maskCanvas, 0, 0, width, height);
    personCtx.filter = "none";
    personCtx.globalCompositeOperation = "source-in";
    personCtx.drawImage(video, 0, 0, width, height);
    personCtx.globalCompositeOperation = "source-over";

    // Blurred background, overscanned so the blur doesn't produce
    // semi-transparent edges, with the person composited on top.
    const ctx = this.#outputCtx;
    const blurPx = Math.round(
      (this.#amount / 100) * MAX_BLUR_PX * (height / 720)
    );

    if (blurPx > 0) {
      ctx.filter = `blur(${blurPx}px)`;
      ctx.drawImage(
        video,
        -blurPx,
        -blurPx,
        width + blurPx * 2,
        height + blurPx * 2
      );
      ctx.filter = "none";
    } else {
      ctx.drawImage(video, 0, 0, width, height);
    }

    ctx.drawImage(this.#personCanvas, 0, 0);
  }

  #paintMask(result) {
    const masks = result.confidenceMasks;
    if (!masks?.length) {
      return;
    }

    // The selfie model has categories background(0) / person(1); some builds
    // emit a single person-confidence mask instead.
    const mask = masks.length > 1 ? masks[1] : masks[0];
    const { width, height } = mask;

    if (
      !this.#maskImageData ||
      this.#maskImageData.width !== width ||
      this.#maskImageData.height !== height
    ) {
      this.#maskCanvas.width = width;
      this.#maskCanvas.height = height;
      this.#maskImageData = this.#maskCtx.createImageData(width, height);
      this.#maskImageData.data.fill(255);
    }

    const values = mask.getAsFloat32Array();
    const data = this.#maskImageData.data;
    for (let i = 0; i < values.length; i++) {
      data[i * 4 + 3] = values[i] * 255;
    }

    this.#maskCtx.putImageData(this.#maskImageData, 0, 0);
  }
}
