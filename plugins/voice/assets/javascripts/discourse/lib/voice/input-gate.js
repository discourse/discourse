const SAMPLE_INTERVAL_MS = 50;
const RELEASE_HOLD_MS = 400;
const THRESHOLD_STORAGE_KEY = "voice_gate_threshold";

// Full scale for the sensitivity slider and the settings meter, in byte
// time-domain RMS units (speech peaks land mid-range). Because both the
// meter and the slider map linearly onto this value, a slider value of N
// sits at N% of the meter — the threshold marker lines up with no extra
// conversion.
export const METER_MAX_RMS = 50;

export function sliderToRms(value) {
  return (Math.max(0, Math.min(100, value)) / 100) * METER_MAX_RMS;
}

export function rmsToPercent(rms) {
  return Math.max(0, Math.min(100, (rms / METER_MAX_RMS) * 100));
}

export function sampleRms(analyser, dataArray) {
  analyser.getByteTimeDomainData(dataArray);
  let sum = 0;
  for (let i = 0; i < dataArray.length; i++) {
    const deviation = dataArray[i] - 128;
    sum += deviation * deviation;
  }
  return Math.sqrt(sum / dataArray.length);
}

// A noise gate for the outgoing mic stream: audio only passes while the
// input level is above the user's sensitivity threshold. The gate holds
// open briefly after the level drops so words aren't clipped mid-sentence,
// and gain changes are ramped to avoid clicks.
export default class InputGateManager {
  static storedSliderValue() {
    try {
      const stored = parseInt(localStorage.getItem(THRESHOLD_STORAGE_KEY), 10);
      if (Number.isFinite(stored)) {
        return Math.max(0, Math.min(100, stored));
      }
    } catch {
      // ignore storage errors
    }
    return 0;
  }

  static storeSliderValue(value) {
    try {
      if (value > 0) {
        localStorage.setItem(THRESHOLD_STORAGE_KEY, String(value));
      } else {
        localStorage.removeItem(THRESHOLD_STORAGE_KEY);
      }
    } catch {
      // ignore storage errors
    }
  }

  #context = null;
  #source = null;
  #analyser = null;
  #gain = null;
  #dataArray = null;
  #sampleTimer = null;
  #thresholdRms = 0;
  #open = false;
  #holdUntil = 0;

  get active() {
    return this.#context !== null;
  }

  setup(upstream, thresholdRms) {
    this.teardown();

    const context = new AudioContext();
    if (context.state === "suspended") {
      context.resume().catch(() => {});
    }

    const source = context.createMediaStreamSource(upstream);
    const analyser = context.createAnalyser();
    analyser.fftSize = 512;
    const gain = context.createGain();
    const destination = context.createMediaStreamDestination();

    source.connect(analyser);
    source.connect(gain);
    gain.connect(destination);

    // Start closed; the first sample above the threshold opens it.
    gain.gain.value = 0;

    this.#context = context;
    this.#source = source;
    this.#analyser = analyser;
    this.#gain = gain;
    this.#dataArray = new Uint8Array(analyser.frequencyBinCount);
    this.#thresholdRms = thresholdRms;
    this.#open = false;
    this.#holdUntil = 0;

    this.#sample();

    return destination.stream;
  }

  setThreshold(thresholdRms) {
    this.#thresholdRms = thresholdRms;
  }

  teardown() {
    if (this.#sampleTimer) {
      clearTimeout(this.#sampleTimer);
      this.#sampleTimer = null;
    }

    if (this.#source) {
      try {
        this.#source.disconnect();
      } catch {
        // ignore
      }
      this.#source = null;
    }

    if (this.#context) {
      try {
        this.#context.close();
      } catch {
        // ignore
      }
      this.#context = null;
    }

    this.#analyser = null;
    this.#gain = null;
    this.#dataArray = null;
    this.#open = false;
  }

  #sample() {
    const rms = sampleRms(this.#analyser, this.#dataArray);
    const now = performance.now();

    if (rms >= this.#thresholdRms) {
      this.#holdUntil = now + RELEASE_HOLD_MS;
      if (!this.#open) {
        this.#open = true;
        this.#gain.gain.setTargetAtTime(1, this.#context.currentTime, 0.005);
      }
    } else if (this.#open && now >= this.#holdUntil) {
      this.#open = false;
      this.#gain.gain.setTargetAtTime(0, this.#context.currentTime, 0.03);
    }

    this.#sampleTimer = setTimeout(() => this.#sample(), SAMPLE_INTERVAL_MS);
  }
}
