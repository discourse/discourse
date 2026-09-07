import { nsUrl } from "./ns-engines";

// How long setup() waits for the worklet's "ready" handshake. Instantiating
// the (already fetched) wasm and warming the model up takes well under a
// second on weak hardware; the margin covers a cold audio thread.
const READY_TIMEOUT_MS = 10000;

// How long a user-gesture setup() waits for the AudioContext to leave
// "suspended" before falling back to the statechange-driven re-resume.
const RESUME_WAIT_MS = 1000;

// Thrown by setup() when a newer setup()/teardown() superseded it (device
// switch, rapid toggling, leaving the room). Callers must treat it as a
// no-op, not a failure: the superseding call owns the pipeline state now.
export class SupersededError extends Error {
  constructor() {
    super("noise suppression setup superseded");
    this.name = "SupersededError";
  }
}

const assetPromises = new Map();

function fetchBytes(file) {
  if (!assetPromises.has(file)) {
    assetPromises.set(
      file,
      fetch(nsUrl(file))
        .then((response) => {
          if (!response.ok) {
            throw new Error(`${file} fetch failed: ${response.status}`);
          }
          return response.arrayBuffer();
        })
        .catch((error) => {
          // A failed fetch is not cached, so a flaky connection doesn't
          // brick the feature until reload.
          assetPromises.delete(file);
          throw error;
        })
    );
  }
  return assetPromises.get(file);
}

// Fetching an engine's model once and keeping the bytes lets re-enables and
// device switches skip the network entirely.
export function prefetchEngineAssets(engine) {
  const assets = { wasm: fetchBytes(engine.wasmFile) };
  if (engine.modelFile) {
    assets.model = fetchBytes(engine.modelFile);
  }
  return Promise.all(Object.values(assets)).then(async () => ({
    wasm: await assets.wasm,
    model: engine.modelFile ? await assets.model : undefined,
  }));
}

function timeout(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export default class NoiseSuppressionManager {
  #context = null;
  #source = null;
  #node = null;
  #epoch = 0;
  #abortReady = null;

  #onRuntimeFailure;

  constructor({ onRuntimeFailure } = {}) {
    this.#onRuntimeFailure = onRuntimeFailure;
  }

  get active() {
    return this.#context !== null;
  }

  // Resolves with the suppressed MediaStream only after the worklet has
  // confirmed the model is loaded and filtering (the "ready" handshake), so
  // a resolved setup() means noise suppression is actually working. Throws
  // SupersededError when a newer setup()/teardown() takes over mid-flight.
  // `engine` is a descriptor from ns-engines.js.
  async setup(rawStream, engine, { userGesture = false } = {}) {
    const epoch = ++this.#epoch;
    const superseded = () => epoch !== this.#epoch;

    const assets = await prefetchEngineAssets(engine);
    if (superseded()) {
      throw new SupersededError();
    }

    const audioContext = new AudioContext();

    // A fresh context starts suspended without recent user activation (e.g.
    // rejoining a room after a reload) and a suspended context outputs
    // silence. statechange re-resumes after OS-level interruptions
    // (Bluetooth profile switches, phone calls).
    const keepRunning = () => {
      if (audioContext.state !== "running") {
        audioContext.resume().catch(() => {});
      }
    };
    audioContext.onstatechange = keepRunning;

    const abort = () => {
      audioContext.onstatechange = null;
      try {
        audioContext.close();
      } catch {
        // ignore
      }
    };

    if (userGesture) {
      // Inside a click handler resume() should settle immediately; if it
      // stays pending (browser quirk), keepRunning picks it up later rather
      // than failing a toggle that would otherwise work.
      await Promise.race([
        audioContext.resume().catch(() => {}),
        timeout(RESUME_WAIT_MS),
      ]);
    } else {
      keepRunning();
    }

    if (superseded()) {
      abort();
      throw new SupersededError();
    }

    try {
      // Worklet modules (unlike Workers) may load cross-origin, so the
      // bundle rides the CDN too.
      await audioContext.audioWorklet.addModule(nsUrl(engine.workletFile));
    } catch (error) {
      abort();
      throw error;
    }

    if (superseded()) {
      abort();
      throw new SupersededError();
    }

    // The engines are mono. Forcing one channel downmixes stereo mics ahead
    // of the worklet; left at the defaults the node mirrors the input's
    // channel count and a stereo mic ships a silent right channel.
    const workletNode = new AudioWorkletNode(
      audioContext,
      "noise-suppression-processor",
      {
        channelCount: 1,
        channelCountMode: "explicit",
        outputChannelCount: [1],
      }
    );

    try {
      await this.#awaitReady(workletNode, assets, superseded);
    } catch (error) {
      abort();
      throw error;
    }

    if (superseded()) {
      abort();
      throw new SupersededError();
    }

    // Live messages after the handshake mean the filter broke mid-call;
    // hand the pipeline the failure so it can fall back to the raw track.
    workletNode.port.onmessage = (event) => {
      const type = event.data?.type;
      if ((type === "bypass" || type === "error") && !superseded()) {
        this.#onRuntimeFailure?.();
      }
    };

    // Audio only starts flowing through the node now that the model is
    // confirmed live; before this point the worklet would pass raw audio
    // through (fail-open) and the toggle would silently lie.
    const source = audioContext.createMediaStreamSource(rawStream);
    const destination = audioContext.createMediaStreamDestination();
    destination.channelCount = 1;
    source.connect(workletNode);
    workletNode.connect(destination);

    this.#context = audioContext;
    this.#source = source;
    this.#node = workletNode;

    return destination.stream;
  }

  #awaitReady(workletNode, assets, superseded) {
    return new Promise((resolve, reject) => {
      let timer = null;
      const settle = (fn, value) => {
        clearTimeout(timer);
        workletNode.port.onmessage = null;
        this.#abortReady = null;
        fn(value);
      };

      // teardown()/a newer setup() must not leave this parked for the full
      // timeout — reject immediately so the superseded caller unwinds.
      this.#abortReady = () => settle(reject, new SupersededError());

      workletNode.port.onmessage = (event) => {
        const { type, message } = event.data || {};
        if (superseded()) {
          settle(reject, new SupersededError());
        } else if (type === "ready") {
          settle(resolve);
        } else if (type === "error") {
          settle(reject, new Error(`engine init failed: ${message}`));
        }
      };

      timer = setTimeout(() => {
        settle(reject, new Error("worklet ready handshake timed out"));
      }, READY_TIMEOUT_MS);

      // The cached bytes stay usable: copies are transferred, not the cache.
      const payload = { wasm: assets.wasm.slice(0) };
      if (assets.model) {
        payload.model = assets.model.slice(0);
      }
      workletNode.port.postMessage(
        { type: "init", assets: payload },
        Object.values(payload)
      );
    });
  }

  teardown() {
    this.#epoch++;
    this.#abortReady?.();

    if (this.#source) {
      try {
        this.#source.disconnect();
      } catch {
        // ignore
      }
      this.#source = null;
    }

    if (this.#node) {
      this.#node.port.onmessage = null;
      try {
        this.#node.disconnect();
      } catch {
        // ignore
      }
      this.#node = null;
    }

    if (this.#context) {
      this.#context.onstatechange = null;
      try {
        this.#context.close();
      } catch {
        // ignore
      }
      this.#context = null;
    }
  }
}
