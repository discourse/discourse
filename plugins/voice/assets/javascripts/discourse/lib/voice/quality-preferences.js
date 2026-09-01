// User-facing quality tiers, ordered lowest to highest. The user's stored
// choice is a preference, not a guarantee: the effective tier is the lowest
// of the user's choice, the room's cap, and the site setting cap, and the
// per-connection bandwidth estimator still adapts below whatever ceiling the
// tier sets.
export const QUALITY_STANDARD = "standard";
export const QUALITY_HIGH = "high";
export const QUALITY_MAXIMUM = "maximum";

export const QUALITY_TIERS = [QUALITY_STANDARD, QUALITY_HIGH, QUALITY_MAXIMUM];

export const SCREEN_CONTENT_TEXT = "text";
export const SCREEN_CONTENT_MOTION = "motion";

const VOICE_STORAGE_KEY = "voice_voice_quality";
const CAMERA_STORAGE_KEY = "voice_camera_quality";
const SCREEN_STORAGE_KEY = "voice_screen_quality";
const SCREEN_CONTENT_STORAGE_KEY = "voice_screen_content";

function readStored(key, allowed, fallback) {
  try {
    const value = localStorage.getItem(key);
    return allowed.includes(value) ? value : fallback;
  } catch {
    return fallback;
  }
}

function store(key, value, fallback) {
  try {
    if (!value || value === fallback) {
      localStorage.removeItem(key);
    } else {
      localStorage.setItem(key, value);
    }
  } catch {
    // ignore storage errors
  }
}

export function preferredVoiceQuality() {
  return readStored(VOICE_STORAGE_KEY, QUALITY_TIERS, QUALITY_STANDARD);
}

export function setPreferredVoiceQuality(tier) {
  store(VOICE_STORAGE_KEY, tier, QUALITY_STANDARD);
}

export function preferredCameraQuality() {
  return readStored(CAMERA_STORAGE_KEY, QUALITY_TIERS, QUALITY_STANDARD);
}

export function setPreferredCameraQuality(tier) {
  store(CAMERA_STORAGE_KEY, tier, QUALITY_STANDARD);
}

export function preferredScreenQuality() {
  return readStored(SCREEN_STORAGE_KEY, QUALITY_TIERS, QUALITY_STANDARD);
}

export function setPreferredScreenQuality(tier) {
  store(SCREEN_STORAGE_KEY, tier, QUALITY_STANDARD);
}

export function preferredScreenContent() {
  return readStored(
    SCREEN_CONTENT_STORAGE_KEY,
    [SCREEN_CONTENT_TEXT, SCREEN_CONTENT_MOTION],
    SCREEN_CONTENT_TEXT
  );
}

export function setPreferredScreenContent(content) {
  store(SCREEN_CONTENT_STORAGE_KEY, content, SCREEN_CONTENT_TEXT);
}

// Tiers a user may pick given the caps: everything up to the lowest cap.
export function allowedQualityTiers(...caps) {
  const highest = clampQuality(QUALITY_MAXIMUM, ...caps);
  return QUALITY_TIERS.slice(0, QUALITY_TIERS.indexOf(highest) + 1);
}

// Lowest of the given tiers; null/undefined caps (e.g. a room with no
// room-level cap) don't constrain.
export function clampQuality(tier, ...caps) {
  let rank = QUALITY_TIERS.indexOf(tier);
  if (rank === -1) {
    rank = 0;
  }

  for (const cap of caps) {
    const capRank = QUALITY_TIERS.indexOf(cap);
    if (capRank !== -1 && capRank < rank) {
      rank = capRank;
    }
  }

  return QUALITY_TIERS[rank];
}
