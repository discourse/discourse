import { isAudio } from "discourse/lib/uploads";

export const AUDIO_WAVEFORM_VERSION = 1;
export const AUDIO_WAVEFORM_BAR_COUNT = 40;

export function getVoiceMessageUpload(uploads) {
  if (uploads?.length !== 1) {
    return;
  }

  const upload = uploads[0];
  if (
    isAudio(upload.original_filename) &&
    isSupportedAudioWaveform(
      upload.audio_waveform,
      upload.audio_waveform_version
    )
  ) {
    return upload;
  }
}

export function isSupportedAudioWaveform(waveform, version) {
  return (
    version === AUDIO_WAVEFORM_VERSION &&
    Array.isArray(waveform) &&
    waveform.length === AUDIO_WAVEFORM_BAR_COUNT &&
    waveform.every(
      (value) => Number.isInteger(value) && value >= 0 && value <= 255
    )
  );
}

export function normalizeAudioPeaks(
  peaks,
  barCount = AUDIO_WAVEFORM_BAR_COUNT
) {
  if (!peaks.length) {
    return;
  }

  const amplitudes = [];

  for (let bar = 0; bar < barCount; bar++) {
    const start = Math.floor((bar / barCount) * peaks.length);
    const end = Math.max(
      start + 1,
      Math.ceil(((bar + 1) / barCount) * peaks.length)
    );
    const samples = peaks.slice(start, end);
    const peak = Math.max(...samples);
    const average =
      samples.reduce((sum, value) => sum + value, 0) / samples.length;
    amplitudes.push(average * 0.7 + peak * 0.3);
  }

  const maximum = Math.max(...amplitudes);
  if (!maximum) {
    return Array(barCount).fill(0);
  }

  return amplitudes.map((amplitude) =>
    Math.round(Math.sqrt(amplitude / maximum) * 255)
  );
}

export function encodeAudioWaveform(peaks) {
  const waveform = normalizeAudioPeaks(peaks);
  if (!waveform) {
    return;
  }

  return window.btoa(String.fromCharCode(...waveform));
}
