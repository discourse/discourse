export const INPUT_DELAY = 250;

let environment = "unknown";

export function setEnvironment(e) {
  if (isTesting()) {
    environment = "testing";
  } else {
    environment = e;
  }
}

export function isTesting() {
  // eslint-disable-next-line no-undef
  return Ember.testing || environment === "testing";
}

// Generally means "before we migrated to Ember CLI"
// eslint-disable-next-line no-undef
let _isLegacy = Ember.VERSION.startsWith("3.12");
export function isLegacyEmber() {
  return _isLegacy;
}

export function isDevelopment() {
  return environment === "development";
}

export function isProduction() {
  return environment === "production";
}
