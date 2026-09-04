import {
  QUALITY_HIGH,
  QUALITY_MAXIMUM,
  QUALITY_STANDARD,
  SCREEN_CONTENT_MOTION,
} from "./quality-preferences";

// Mesh budget: every watcher costs the sender a full encode, so resolution
// and bitrate scale down as the watcher count grows. Each connection's
// bandwidth estimator still adapts per-link below these ceilings.
//
// The quality tier moves the ladder's rungs; "maximum" pins the top rung and
// opts out of watcher-count downscaling entirely — the user has explicitly
// accepted the multiplied upload/CPU cost, and congestion control still
// protects each individual link.
const SCREEN_ENCODINGS = {
  [QUALITY_STANDARD]: {
    maxBitrate: 2_500_000,
    scaleResolutionDownBy: 1,
    maxFramerate: 15,
  },
  [QUALITY_HIGH]: {
    maxBitrate: 6_000_000,
    scaleResolutionDownBy: 1,
    maxFramerate: 30,
  },
  [QUALITY_MAXIMUM]: {
    maxBitrate: 15_000_000,
    scaleResolutionDownBy: 1,
    maxFramerate: 60,
  },
};

const CAMERA_LADDERS = {
  [QUALITY_STANDARD]: [
    { maxBitrate: 1_200_000, scaleResolutionDownBy: 1, maxFramerate: 24 },
    { maxBitrate: 700_000, scaleResolutionDownBy: 1.5, maxFramerate: 24 },
    { maxBitrate: 400_000, scaleResolutionDownBy: 2, maxFramerate: 15 },
  ],
  [QUALITY_HIGH]: [
    { maxBitrate: 2_500_000, scaleResolutionDownBy: 1, maxFramerate: 24 },
    { maxBitrate: 1_200_000, scaleResolutionDownBy: 1.5, maxFramerate: 24 },
    { maxBitrate: 700_000, scaleResolutionDownBy: 2, maxFramerate: 15 },
  ],
};

const CAMERA_MAXIMUM_ENCODING = {
  maxBitrate: 8_000_000,
  scaleResolutionDownBy: 1,
  maxFramerate: 30,
};

// Opus speech defaults are left alone on the standard tier; higher tiers
// raise the ceiling for good microphones. Bandwidth is negligible next to
// video either way.
const VOICE_BITRATES = {
  [QUALITY_STANDARD]: null,
  [QUALITY_HIGH]: 64_000,
  [QUALITY_MAXIMUM]: 128_000,
};

export function screenCaptureFramerate(tier) {
  return SCREEN_ENCODINGS[tier]?.maxFramerate ?? 15;
}

function encodingFor(kind, senderCount, tier = QUALITY_STANDARD) {
  if (kind === "screen") {
    return SCREEN_ENCODINGS[tier] ?? SCREEN_ENCODINGS[QUALITY_STANDARD];
  }

  if (tier === QUALITY_MAXIMUM) {
    return CAMERA_MAXIMUM_ENCODING;
  }

  const ladder = CAMERA_LADDERS[tier] ?? CAMERA_LADDERS[QUALITY_STANDARD];
  if (senderCount <= 3) {
    return ladder[0];
  }
  if (senderCount <= 6) {
    return ladder[1];
  }
  return ladder[2];
}

export function cameraEncodingFor(tier) {
  return encodingFor("camera", 1, tier);
}

export function screenEncodingFor(tier) {
  return encodingFor("screen", 1, tier);
}

export async function applyVideoQuality(
  senders,
  kind,
  { tier = QUALITY_STANDARD, screenContent } = {}
) {
  if (!senders.length) {
    return;
  }

  const encoding = encodingFor(kind, senders.length, tier);
  const preserveMotion =
    kind !== "screen" || screenContent === SCREEN_CONTENT_MOTION;

  for (const sender of senders) {
    try {
      const parameters = sender.getParameters();
      parameters.degradationPreference = preserveMotion
        ? "maintain-framerate"
        : "maintain-resolution";
      if (!parameters.encodings?.length) {
        parameters.encodings = [{}];
      }
      Object.assign(parameters.encodings[0], encoding);
      await sender.setParameters(parameters);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn("[voice] failed to apply video quality", error);
    }
  }
}

export async function applyVoiceQuality(senders, tier = QUALITY_STANDARD) {
  const bitrate = VOICE_BITRATES[tier];

  for (const sender of senders) {
    try {
      const parameters = sender.getParameters();
      if (!parameters.encodings?.length) {
        parameters.encodings = [{}];
      }
      if (bitrate) {
        parameters.encodings[0].maxBitrate = bitrate;
      } else {
        delete parameters.encodings[0].maxBitrate;
      }
      await sender.setParameters(parameters);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn("[voice] failed to apply voice quality", error);
    }
  }
}

export function voiceBitrateFor(tier) {
  return VOICE_BITRATES[tier] ?? null;
}

// Opus defaults target speech bitrates; content audio gets a higher ceiling
// so music doesn't sound underwater. Still small next to the video budget.
export async function applyScreenAudioQuality(sender) {
  try {
    const parameters = sender.getParameters();
    if (!parameters.encodings?.length) {
      parameters.encodings = [{}];
    }
    parameters.encodings[0].maxBitrate = 128_000;
    await sender.setParameters(parameters);
  } catch (error) {
    // eslint-disable-next-line no-console
    console.warn("[voice] failed to apply screen audio quality", error);
  }
}
