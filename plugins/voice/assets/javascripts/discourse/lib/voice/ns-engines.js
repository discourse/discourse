import { i18n } from "discourse-i18n";

export { voiceAssetUrl as nsUrl } from "./voice-assets";

// The selectable AI noise-suppression engines. Every engine ships a worklet
// bundle speaking the same protocol (src/ns-worklet/runtime.js in the
// discourse_voice_assets gem, which vendors the built assets): asset bytes
// posted in, ready/error handshake out, mono frames filtered at the
// engine's own rate. Filenames are the gem's stable names, resolved to
// versioned URLs through nsUrl().
//
// Order here is the order shown in the mode selectors.
export const NS_ENGINES = {
  rnnoise: {
    workletFile: "rnnoise/rnnoise-worklet.js",
    wasmFile: "rnnoise/rnnoise.wasm",
  },
  dtln: {
    workletFile: "dtln/dtln-worklet.js",
    wasmFile: "dtln/dtln.wasm",
  },
  dfn3: {
    workletFile: "dfn3/dfn3-worklet.js",
    wasmFile: "dfn3/dfn3.wasm",
    modelFile: "dfn3/dfn3-model.bin",
  },
};

export function engineForMode(mode) {
  if (!mode?.startsWith?.("ai:")) {
    return null;
  }
  return NS_ENGINES[mode.slice(3)] ?? null;
}

// "ai:dtln" → the "…noise_suppression_modes.ai_dtln" translation ("ai:dtln"
// itself stays the stored/mode value; colons just make poor YAML keys).
export function noiseSuppressionModeLabel(mode) {
  return i18n(
    `voice.voice_settings.noise_suppression_modes.${mode.replace(":", "_")}`
  );
}
