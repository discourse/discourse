// Barrel for the in-call UI, so the global layer can pull it in with a single dynamic import.
// The layer renders on every page, so importing these eagerly would put most of the plugin in
// the bundle for every request.
export { default as CallWidget } from "./call-widget";
export { default as VoiceCanvas } from "./voice-canvas";
