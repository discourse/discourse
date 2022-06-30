import deprecated from "discourse-common/lib/deprecated";

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
  deprecated("`isLegacyEmber()` is now deprecated and always returns true", {
    dropFrom: "3.0.0.beta1",
  });
  return _isLegacy;
}

export function isDevelopment() {
  return environment === "development";
}

export function isProduction() {
  return environment === "production";
}
