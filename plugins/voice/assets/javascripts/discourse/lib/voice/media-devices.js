import { i18n } from "discourse-i18n";
import { processingConstraints } from "./audio-processing";

const INPUT_STORAGE_KEY = "voice_audio_input_device";
const OUTPUT_STORAGE_KEY = "voice_audio_output_device";
const VIDEO_INPUT_STORAGE_KEY = "voice_video_input_device";

// Sentinel meaning "no explicit device": getUserMedia runs without a
// deviceId constraint and playback sticks to the browser default sink.
export const SYSTEM_DEFAULT_DEVICE_ID = "system_default";

function readStoredDevice(key) {
  try {
    return localStorage.getItem(key) || SYSTEM_DEFAULT_DEVICE_ID;
  } catch {
    return SYSTEM_DEFAULT_DEVICE_ID;
  }
}

function storeDevice(key, deviceId) {
  try {
    if (!deviceId || deviceId === SYSTEM_DEFAULT_DEVICE_ID) {
      localStorage.removeItem(key);
    } else {
      localStorage.setItem(key, deviceId);
    }
  } catch {
    // ignore storage errors
  }
}

export function preferredInputDeviceId() {
  return readStoredDevice(INPUT_STORAGE_KEY);
}

export function setPreferredInputDeviceId(deviceId) {
  storeDevice(INPUT_STORAGE_KEY, deviceId);
}

export function preferredOutputDeviceId() {
  return readStoredDevice(OUTPUT_STORAGE_KEY);
}

export function setPreferredOutputDeviceId(deviceId) {
  storeDevice(OUTPUT_STORAGE_KEY, deviceId);
}

export function preferredVideoInputDeviceId() {
  return readStoredDevice(VIDEO_INPUT_STORAGE_KEY);
}

export function setPreferredVideoInputDeviceId(deviceId) {
  storeDevice(VIDEO_INPUT_STORAGE_KEY, deviceId);
}

// exact: a switch must land on the requested device or fail loudly; the
// browser can satisfy a soft request from the already-open device.
export function audioConstraints(
  deviceId = preferredInputDeviceId(),
  { exact = false } = {}
) {
  const constraints = processingConstraints();
  if (deviceId && deviceId !== SYSTEM_DEFAULT_DEVICE_ID) {
    constraints.deviceId = exact ? { exact: deviceId } : { ideal: deviceId };
  }
  return constraints;
}

// Capture dimensions per quality tier; the encoder ceilings in
// video-quality.js scale from whatever was captured, so both move together.
const CAMERA_CAPTURE = {
  standard: { width: 1280, height: 720, frameRate: 24 },
  high: { width: 1920, height: 1080, frameRate: 24 },
  maximum: { width: 1920, height: 1080, frameRate: 30 },
};

// Ideal dimensions match the device orientation so a phone held in portrait
// sends an upright portrait frame; the grid lays out whatever aspect the
// camera actually delivers. The swap only applies on touch devices: the
// orientation media query tracks the viewport, and a tall desktop window
// must not make Chromium center-crop a landscape webcam into portrait.
export function cameraConstraints(
  deviceId = preferredVideoInputDeviceId(),
  tier = "standard",
  { exact = false } = {}
) {
  const capture = CAMERA_CAPTURE[tier] ?? CAMERA_CAPTURE.standard;
  const rotatesWithScreen =
    navigator.userAgentData?.mobile ??
    window.matchMedia?.("(pointer: coarse)")?.matches ??
    false;
  const portrait =
    rotatesWithScreen &&
    (window.matchMedia?.("(orientation: portrait)")?.matches ?? false);
  const [idealWidth, idealHeight] = portrait
    ? [capture.height, capture.width]
    : [capture.width, capture.height];

  // frameRate needs an ideal, not just a ceiling: with only a max, every
  // lower rate satisfies the constraint equally and Chromium can settle on
  // a webcam's 5fps uncompressed modes.
  const constraints = {
    width: { ideal: idealWidth },
    height: { ideal: idealHeight },
    frameRate: { ideal: capture.frameRate, max: capture.frameRate },
  };

  if (deviceId && deviceId !== SYSTEM_DEFAULT_DEVICE_ID) {
    constraints.deviceId = exact ? { exact: deviceId } : { ideal: deviceId };
  }

  return constraints;
}

export function outputSelectionSupported() {
  return (
    typeof HTMLMediaElement !== "undefined" &&
    "setSinkId" in HTMLMediaElement.prototype
  );
}

export async function enumerateAudioDevices() {
  const inputs = [];
  const outputs = [];

  if (!navigator.mediaDevices?.enumerateDevices) {
    return { inputs, outputs };
  }

  let devices;
  try {
    devices = await navigator.mediaDevices.enumerateDevices();
  } catch {
    return { inputs, outputs };
  }

  for (const device of devices) {
    if (device.kind !== "audioinput" && device.kind !== "audiooutput") {
      continue;
    }

    // Before mic permission is granted browsers return placeholder entries
    // with empty deviceIds; they can't be selected, so skip them.
    if (!device.deviceId) {
      continue;
    }

    const list = device.kind === "audioinput" ? inputs : outputs;
    list.push({
      id: device.deviceId,
      name:
        device.label ||
        i18n("voice.devices.unknown_device", {
          index: list.length + 1,
        }),
    });
  }

  return { inputs, outputs };
}

export async function enumerateVideoDevices() {
  const inputs = [];

  if (!navigator.mediaDevices?.enumerateDevices) {
    return inputs;
  }

  let devices;
  try {
    devices = await navigator.mediaDevices.enumerateDevices();
  } catch {
    return inputs;
  }

  for (const device of devices) {
    if (device.kind !== "videoinput" || !device.deviceId) {
      continue;
    }

    inputs.push({
      id: device.deviceId,
      name:
        device.label ||
        i18n("voice.devices.unknown_device", {
          index: inputs.length + 1,
        }),
    });
  }

  return inputs;
}

export function applyOutputDevice(element, deviceId) {
  if (!outputSelectionSupported() || typeof element?.setSinkId !== "function") {
    return;
  }

  const sinkId =
    !deviceId || deviceId === SYSTEM_DEFAULT_DEVICE_ID ? "" : deviceId;

  if (element.sinkId === sinkId) {
    return;
  }

  element.setSinkId(sinkId).catch((error) => {
    // eslint-disable-next-line no-console
    console.warn("[voice] failed to set audio output device", error);
  });
}
