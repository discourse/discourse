import { NS_ENGINES } from "./ns-engines";

// Per-device preferences for the browser's microphone processing chain and
// the noise suppression mode. Echo cancellation and automatic gain control
// default to on (matching what browsers do when the constraints are absent);
// they are stored only when the user turns one off.
//
// Noise suppression modes:
//   "none"         — no filtering at all
//   "standard"     — the browser's native noise suppression
//   "ai:<engine>"  — an AI worklet engine (see ns-engines.js); native
//                    suppression is turned OFF so the two filters don't
//                    stack (stacked suppressors produce the classic
//                    underwater/musical artifacts)

const EC_STORAGE_KEY = "voice:echo-cancellation";
const AGC_STORAGE_KEY = "voice:auto-gain-control";
const NS_MODE_STORAGE_KEY = "voice:noise-suppression-mode";
const LEGACY_NS_STORAGE_KEY = "voice:noise-suppression";

export const NOISE_SUPPRESSION_MODES = [
  "none",
  "standard",
  ...Object.keys(NS_ENGINES).map((id) => `ai:${id}`),
];

export function isAiMode(mode) {
  return !!mode?.startsWith?.("ai:");
}

function readDefaultOnFlag(key) {
  try {
    return localStorage.getItem(key) !== "0";
  } catch {
    return true;
  }
}

function storeDefaultOnFlag(key, enabled) {
  try {
    if (enabled) {
      localStorage.removeItem(key);
    } else {
      localStorage.setItem(key, "0");
    }
  } catch {
    // ignore storage errors
  }
}

export function echoCancellationPreferred() {
  return readDefaultOnFlag(EC_STORAGE_KEY);
}

export function setEchoCancellationPreferred(enabled) {
  storeDefaultOnFlag(EC_STORAGE_KEY, enabled);
}

export function autoGainControlPreferred() {
  return readDefaultOnFlag(AGC_STORAGE_KEY);
}

export function setAutoGainControlPreferred(enabled) {
  storeDefaultOnFlag(AGC_STORAGE_KEY, enabled);
}

export function preferredNoiseSuppressionMode() {
  try {
    const mode = localStorage.getItem(NS_MODE_STORAGE_KEY);
    if (NOISE_SUPPRESSION_MODES.includes(mode)) {
      return mode;
    }
    // Two generations of stored values predate per-engine modes: the plain
    // "ai" mode, and before that a boolean where "1" meant the DTLN worklet
    // was on. Both meant DTLN.
    if (mode === "ai" || localStorage.getItem(LEGACY_NS_STORAGE_KEY) === "1") {
      return "ai:dtln";
    }
  } catch {
    // fall through to the default
  }
  return "standard";
}

export function setPreferredNoiseSuppressionMode(mode) {
  if (!NOISE_SUPPRESSION_MODES.includes(mode)) {
    return;
  }
  try {
    localStorage.setItem(NS_MODE_STORAGE_KEY, mode);
    localStorage.removeItem(LEGACY_NS_STORAGE_KEY);
  } catch {
    // ignore storage errors
  }
}

// The audio-processing member of getUserMedia constraints. Explicit even for
// the defaults, so what the pipeline believes and what the browser applies
// can't drift apart.
export function processingConstraints() {
  return {
    echoCancellation: echoCancellationPreferred(),
    autoGainControl: autoGainControlPreferred(),
    noiseSuppression: preferredNoiseSuppressionMode() === "standard",
  };
}
