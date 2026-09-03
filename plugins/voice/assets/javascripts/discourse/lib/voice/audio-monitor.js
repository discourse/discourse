const SAMPLE_INTERVAL_MS = 100;
const FFT_SIZE = 2048;

// Detection uses an adaptive noise floor with hysteresis: speech must clear
// the floor by a wide margin to start, but only a narrow one to continue, so
// quiet trailing syllables don't flap the indicator. RMS values are on the
// float sample scale (0..1).
const MIN_START_RMS = 0.006;
const MIN_SUSTAIN_RMS = 0.003;
const START_FLOOR_MULTIPLIER = 3;
const SUSTAIN_FLOOR_MULTIPLIER = 1.6;
const MAX_NOISE_FLOOR = 0.1;
const INITIAL_NOISE_FLOOR = 0.02;

// The floor adapts down fast but up slowly, so sustained speech isn't
// absorbed into it.
const FLOOR_DECAY = 0.3;
const FLOOR_RISE = 0.02;

// How long the signal may stay below the sustain threshold before the
// speaker is considered done — covers pauses between words.
const HANGOVER_MS = 700;

export default class AudioMonitor {
  static peerKey(roomId, userId) {
    return `${roomId}:${userId}`;
  }

  #monitors = new Map();
  #audioContext = null;
  #sampleTimer = null;

  #onSpeakingChange;
  #onVoiceActivity;

  constructor({ onSpeakingChange, onVoiceActivity }) {
    this.#onSpeakingChange = onSpeakingChange;
    this.#onVoiceActivity = onVoiceActivity;
  }

  ensure(roomId, userId, stream, isCurrentUser) {
    if (!roomId || !userId || !stream) {
      return;
    }

    const key = AudioMonitor.peerKey(roomId, userId);
    const existing = this.#monitors.get(key);
    if (existing?.stream === stream) {
      return;
    }

    if (existing) {
      this.teardown(roomId, userId);
    }

    try {
      const audioContext = this.#ensureAudioContext();
      if (!audioContext) {
        return;
      }

      const source = audioContext.createMediaStreamSource(stream);
      const analyser = audioContext.createAnalyser();
      analyser.fftSize = FFT_SIZE;
      source.connect(analyser);

      this.#monitors.set(key, {
        roomId,
        userId,
        stream,
        source,
        analyser,
        isCurrentUser,
        floatData: analyser.getFloatTimeDomainData
          ? new Float32Array(analyser.fftSize)
          : null,
        byteData: analyser.getFloatTimeDomainData
          ? null
          : new Uint8Array(analyser.frequencyBinCount),
        speaking: false,
        lastVoiceAt: 0,
        noiseFloor: INITIAL_NOISE_FLOOR,
      });

      this.#startSampling();
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn("[voice] failed to initialize audio monitor", error);
    }
  }

  teardown(roomId, userId) {
    if (!roomId || !userId) {
      return;
    }

    const key = AudioMonitor.peerKey(roomId, userId);
    const monitor = this.#monitors.get(key);
    if (!monitor) {
      return;
    }

    this.#stopMonitor(monitor);
    this.#monitors.delete(key);
    this.#onSpeakingChange(roomId, userId, false);
    this.#maybeReleaseResources();
  }

  teardownRoom(roomId) {
    Array.from(this.#monitors.keys()).forEach((key) => {
      if (key.startsWith(`${roomId}:`)) {
        const [, userId] = key.split(":");
        this.teardown(roomId, Number(userId));
      }
    });
  }

  destroyAll() {
    this.#monitors.forEach((monitor) => this.#stopMonitor(monitor));
    this.#monitors.clear();
    this.#maybeReleaseResources();
  }

  #ensureAudioContext() {
    if (!this.#audioContext || this.#audioContext.state === "closed") {
      const audioContextClass =
        typeof window !== "undefined" &&
        (window.AudioContext || window.webkitAudioContext);

      if (!audioContextClass) {
        return null;
      }

      this.#audioContext = new audioContextClass();
    }

    // Contexts created before a user gesture start suspended and only
    // produce zeros; resume is safe to call repeatedly.
    if (this.#audioContext.state === "suspended") {
      this.#audioContext.resume?.().catch?.(() => {});
    }

    return this.#audioContext;
  }

  #startSampling() {
    if (this.#sampleTimer) {
      return;
    }

    const tick = () => {
      this.#monitors.forEach((monitor) => this.#sampleMonitor(monitor));
      this.#sampleTimer = setTimeout(tick, SAMPLE_INTERVAL_MS);
    };

    tick();
  }

  #sampleMonitor(monitor) {
    const rms = this.#measureRms(monitor);

    if (rms < monitor.noiseFloor) {
      monitor.noiseFloor += (rms - monitor.noiseFloor) * FLOOR_DECAY;
    } else if (!monitor.speaking) {
      monitor.noiseFloor +=
        (Math.min(rms, MAX_NOISE_FLOOR) - monitor.noiseFloor) * FLOOR_RISE;
    }

    const threshold = monitor.speaking
      ? Math.max(MIN_SUSTAIN_RMS, monitor.noiseFloor * SUSTAIN_FLOOR_MULTIPLIER)
      : Math.max(MIN_START_RMS, monitor.noiseFloor * START_FLOOR_MULTIPLIER);

    if (rms >= threshold) {
      monitor.lastVoiceAt = Date.now();

      if (monitor.isCurrentUser) {
        this.#onVoiceActivity();
      }

      if (!monitor.speaking) {
        monitor.speaking = true;
        this.#onSpeakingChange(monitor.roomId, monitor.userId, true);
      }
    } else if (
      monitor.speaking &&
      Date.now() - monitor.lastVoiceAt >= HANGOVER_MS
    ) {
      monitor.speaking = false;
      this.#onSpeakingChange(monitor.roomId, monitor.userId, false);
    }
  }

  #measureRms(monitor) {
    const { analyser } = monitor;
    let sum = 0;

    if (monitor.floatData) {
      analyser.getFloatTimeDomainData(monitor.floatData);
      for (let i = 0; i < monitor.floatData.length; i++) {
        sum += monitor.floatData[i] * monitor.floatData[i];
      }
      return Math.sqrt(sum / monitor.floatData.length);
    }

    analyser.getByteTimeDomainData(monitor.byteData);
    for (let i = 0; i < monitor.byteData.length; i++) {
      const deviation = (monitor.byteData[i] - 128) / 128;
      sum += deviation * deviation;
    }
    return Math.sqrt(sum / monitor.byteData.length);
  }

  #stopMonitor(monitor) {
    try {
      monitor.source.disconnect();
    } catch {
      // ignore
    }
  }

  #maybeReleaseResources() {
    if (this.#monitors.size > 0) {
      return;
    }

    if (this.#sampleTimer) {
      clearTimeout(this.#sampleTimer);
      this.#sampleTimer = null;
    }

    if (this.#audioContext) {
      this.#audioContext.close?.();
      this.#audioContext = null;
    }
  }
}
