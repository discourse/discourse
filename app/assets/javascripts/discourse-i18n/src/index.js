// Eventually, we would like to flip things around, where this package hosts
// the actual I18n code, see https://github.com/discourse/discourse/pull/23867

if (!"I18n" in globalThis) {
  throw new Error("I18n not loaded!");
}

// Re-export a default/global instance
export default globalThis.I18n;
