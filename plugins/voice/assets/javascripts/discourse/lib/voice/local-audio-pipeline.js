import { tracked } from "@glimmer/tracking";
import {
  autoGainControlPreferred,
  echoCancellationPreferred,
  isAiMode,
  preferredNoiseSuppressionMode,
  setAutoGainControlPreferred,
  setEchoCancellationPreferred,
  setPreferredNoiseSuppressionMode,
} from "./audio-processing";
import InputGateManager, { sliderToRms } from "./input-gate";
import {
  audioConstraints,
  preferredInputDeviceId,
  setPreferredInputDeviceId,
} from "./media-devices";
import NoiseSuppressionManager, { SupersededError } from "./noise-suppression";
import { engineForMode } from "./ns-engines";

// Owns the local microphone pipeline: raw mic (with the browser's echo
// cancellation / auto gain / native noise suppression applied per the stored
// preferences) → optional AI noise suppression → optional input gate → the
// published `stream`. All restructures of the pipeline (device switch,
// processing changes, suppression mode, gate crossing zero) notify the
// service so it can re-sync monitors and move peers onto the new track.
export default class LocalAudioPipeline {
  // "none" | "standard" (browser native) | "ai:<engine>" (see ns-engines.js).
  @tracked noiseSuppressionMode = preferredNoiseSuppressionMode();

  // "off" | "starting" | "on" — the AI worklet's lifecycle; "on" means the
  // ready handshake confirmed it is filtering. Always "off" outside AI modes.
  @tracked noiseSuppressionState = "off";

  @tracked echoCancellation = echoCancellationPreferred();
  @tracked autoGainControl = autoGainControlPreferred();
  @tracked stream = null;
  @tracked gateThreshold = InputGateManager.storedSliderValue();
  @tracked inputDeviceId = preferredInputDeviceId();

  // Why the last acquisition failed (a getUserMedia DOMException); lets the
  // service distinguish a browser-level permission block from a missing or
  // busy device. Null after a successful acquisition.
  lastAcquisitionError = null;

  #rawStream = null;
  #upstream = null;
  #noiseSuppression;
  #inputGate;
  #onStreamChanged;
  #onSuppressionFailed;
  #replaceTrackOnPeers;

  // Serializes every pipeline restructure. Suppression setup awaits a
  // multi-second worklet handshake, and restructures can be triggered from
  // several controls at once; interleaving a mode change with a device
  // switch corrupts which stream peers end up on.
  #queue = Promise.resolve();

  constructor({ onStreamChanged, onSuppressionFailed, replaceTrackOnPeers }) {
    this.#onStreamChanged = onStreamChanged;
    this.#onSuppressionFailed = onSuppressionFailed;
    this.#replaceTrackOnPeers = replaceTrackOnPeers;

    this.#noiseSuppression = new NoiseSuppressionManager({
      onRuntimeFailure: () => this.#handleSuppressionRuntimeFailure(),
    });

    this.#inputGate = new InputGateManager();
  }

  get noiseSuppressionEnabled() {
    return this.noiseSuppressionState === "on";
  }

  acquireMicrophone() {
    return this.#serialize(() => this.#acquireMicrophone());
  }

  setNoiseSuppressionMode(mode) {
    return this.#serialize(() => this.#setNoiseSuppressionMode(mode));
  }

  setEchoCancellation(enabled) {
    return this.#serialize(() => {
      this.echoCancellation = enabled;
      setEchoCancellationPreferred(enabled);
      return this.#reacquireQuietly();
    });
  }

  setAutoGainControl(enabled) {
    return this.#serialize(() => {
      this.autoGainControl = enabled;
      setAutoGainControlPreferred(enabled);
      return this.#reacquireQuietly();
    });
  }

  setInputDevice(deviceId) {
    return this.#serialize(() => this.#setInputDevice(deviceId));
  }

  async setGateThreshold(value) {
    const clamped = Math.max(0, Math.min(100, Math.round(value)));
    this.gateThreshold = clamped;
    InputGateManager.storeSliderValue(clamped);

    if (!this.#upstream) {
      return;
    }

    // Adjusting an already-running gate is just a new compare value; only
    // crossing zero (gate off ↔ on) restructures the pipeline and needs the
    // peers' senders updated.
    if (this.#inputGate.active && clamped > 0) {
      this.#inputGate.setThreshold(sliderToRms(clamped));
      return;
    }
    if (!this.#inputGate.active && clamped === 0) {
      return;
    }

    this.#setOutgoingStream(this.#upstream);
    await this.#replaceTrackOnPeers();
  }

  // Intentionally synchronous and not serialized: leaving the room must take
  // effect immediately. teardown() bumps the suppression epoch, so any
  // in-flight setup unwinds as superseded instead of publishing a stream.
  stop() {
    this.#noiseSuppression.teardown();
    this.noiseSuppressionState = "off";
    this.#inputGate.teardown();
    this.#upstream = null;

    if (this.#rawStream) {
      this.#rawStream.getTracks().forEach((track) => track.stop());
      this.#rawStream = null;
    }

    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }

    this.#onStreamChanged();
  }

  #serialize(task) {
    const run = this.#queue.then(task, task);
    this.#queue = run.then(
      () => {},
      () => {}
    );
    return run;
  }

  async #acquireMicrophone() {
    try {
      const rawStream = await navigator.mediaDevices.getUserMedia({
        audio: audioConstraints(this.inputDeviceId),
      });
      this.lastAcquisitionError = null;
      // eslint-disable-next-line no-console
      console.log("[voice] local stream obtained");

      this.#rawStream = rawStream;

      try {
        // A failed DTLN setup here is transient (the preference survives;
        // the next acquisition retries) and already fell back to the raw
        // stream, which has native suppression off in AI mode — no reacquire
        // mid-join, the user can flip the mode if it persists.
        await this.#buildProcessedStream(rawStream);
      } catch (error) {
        if (error instanceof SupersededError) {
          return true;
        }
        throw error;
      }

      return true;
    } catch (error) {
      this.lastAcquisitionError = error;
      // eslint-disable-next-line no-console
      console.warn("[voice] failed to obtain local stream", error);
      return false;
    }
  }

  async #setNoiseSuppressionMode(mode) {
    if (mode === this.noiseSuppressionMode) {
      return;
    }

    const previousMode = this.noiseSuppressionMode;
    this.noiseSuppressionMode = mode;
    setPreferredNoiseSuppressionMode(mode);

    // Without a live mic the stored preference applies on next acquisition.
    if (!this.#rawStream) {
      return;
    }

    let reacquired;
    try {
      // Native suppression is part of the getUserMedia constraints, so any
      // mode change needs a fresh capture, not just a graph restructure.
      reacquired = await this.#reacquire({ userGesture: true });
    } catch (error) {
      if (error instanceof SupersededError) {
        return;
      }
      // Capture failed: the current stream is untouched, so just undo the
      // preference.
      // eslint-disable-next-line no-console
      console.warn("[voice] failed to apply noise suppression mode", error);
      this.noiseSuppressionMode = previousMode;
      setPreferredNoiseSuppressionMode(previousMode);
      return;
    }

    if (reacquired) {
      // eslint-disable-next-line no-console
      console.log(`[voice] noise suppression mode: ${mode}`);
      return;
    }

    // AI setup failed on an explicit user action: put the preference back
    // and tell them, mirroring the old toggle's revert behavior.
    this.noiseSuppressionMode = previousMode;
    setPreferredNoiseSuppressionMode(previousMode);
    this.#onSuppressionFailed();
    try {
      await this.#reacquire({ userGesture: true });
    } catch (error) {
      if (!(error instanceof SupersededError)) {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to restore previous mode", error);
      }
    }
  }

  async #setInputDevice(deviceId) {
    const previousDeviceId = this.inputDeviceId;
    this.inputDeviceId = deviceId;
    setPreferredInputDeviceId(deviceId);

    if (!this.#rawStream) {
      return true;
    }

    try {
      await this.#reacquire({ userGesture: true, exactDevice: true });
      return true;
    } catch (error) {
      if (error instanceof SupersededError) {
        return true;
      }
      // eslint-disable-next-line no-console
      console.warn("[voice] failed to switch input device", error);
      this.inputDeviceId = previousDeviceId;
      setPreferredInputDeviceId(previousDeviceId);
      return false;
    }
  }

  // Captures a fresh raw stream under the current constraints and rebuilds
  // the processed pipeline on it. Returns false when the DTLN setup failed
  // (the raw stream is published instead); throws SupersededError or
  // getUserMedia errors.
  async #reacquire({ userGesture = false, exactDevice = false } = {}) {
    const newRawStream = await navigator.mediaDevices.getUserMedia({
      audio: audioConstraints(this.inputDeviceId, { exact: exactDevice }),
    });

    const oldRawStream = this.#rawStream;
    this.#rawStream = newRawStream;

    let suppressionOk;
    try {
      suppressionOk = await this.#buildProcessedStream(newRawStream, {
        userGesture,
      });
    } catch (error) {
      if (error instanceof SupersededError) {
        // The superseding restructure owns the published stream; this
        // capture is going nowhere.
        newRawStream.getTracks().forEach((track) => track.stop());
      }
      throw error;
    }

    oldRawStream?.getTracks().forEach((track) => track.stop());
    await this.#replaceTrackOnPeers();
    return suppressionOk;
  }

  // For EC/AGC changes: a capture failure just keeps the current stream (the
  // preference still applies on the next acquisition).
  async #reacquireQuietly() {
    if (!this.#rawStream) {
      return;
    }
    try {
      await this.#reacquire({ userGesture: true });
    } catch (error) {
      if (error instanceof SupersededError) {
        return;
      }
      // eslint-disable-next-line no-console
      console.warn("[voice] failed to apply audio processing change", error);
    }
  }

  // Builds suppression + gate on top of a raw stream and publishes the
  // result. Returns false when AI mode was requested but the worklet setup
  // failed (raw stream published as fallback). Throws SupersededError.
  async #buildProcessedStream(rawStream, { userGesture = false } = {}) {
    this.#noiseSuppression.teardown();

    const engine = engineForMode(this.noiseSuppressionMode);
    if (!engine) {
      this.noiseSuppressionState = "off";
      this.#setOutgoingStream(rawStream);
      return true;
    }

    this.noiseSuppressionState = "starting";
    try {
      const suppressed = await this.#noiseSuppression.setup(rawStream, engine, {
        userGesture,
      });
      this.noiseSuppressionState = "on";
      this.#setOutgoingStream(suppressed);
      // eslint-disable-next-line no-console
      console.log("[voice] AI noise suppression enabled");
      return true;
    } catch (error) {
      if (error instanceof SupersededError) {
        throw error;
      }
      // eslint-disable-next-line no-console
      console.warn("[voice] AI noise suppression setup failed", error);
      this.noiseSuppressionState = "off";
      this.#setOutgoingStream(rawStream);
      return false;
    }
  }

  // The worklet reported a mid-call breakdown (repeated engine failures or a
  // late init error): drop back to standard suppression so peers don't keep
  // listening through a dead passthrough graph or an unfiltered mic.
  #handleSuppressionRuntimeFailure() {
    this.#serialize(async () => {
      if (!isAiMode(this.noiseSuppressionMode) || !this.#rawStream) {
        return;
      }
      this.noiseSuppressionMode = "standard";
      setPreferredNoiseSuppressionMode("standard");
      this.#onSuppressionFailed();
      try {
        await this.#reacquire();
      } catch (error) {
        if (error instanceof SupersededError) {
          return;
        }
        // Capture failed: publish what we still have rather than nothing.
        // eslint-disable-next-line no-console
        console.warn(
          "[voice] failed to reacquire after suppression breakdown",
          error
        );
        this.#noiseSuppression.teardown();
        this.noiseSuppressionState = "off";
        this.#setOutgoingStream(this.#rawStream);
        await this.#replaceTrackOnPeers();
      }
    });
  }

  // Final hop of the pipeline: the `upstream` argument is the raw mic or the
  // noise-suppressed stream; the gate wraps it when enabled.
  #setOutgoingStream(upstream) {
    this.#upstream = upstream;
    this.#inputGate.teardown();

    let stream = upstream;
    if (upstream && this.gateThreshold > 0) {
      try {
        stream = this.#inputGate.setup(
          upstream,
          sliderToRms(this.gateThreshold)
        );
      } catch (error) {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to set up input gate", error);
        stream = upstream;
      }
    }

    this.stream = stream;
    this.#onStreamChanged();
  }
}
