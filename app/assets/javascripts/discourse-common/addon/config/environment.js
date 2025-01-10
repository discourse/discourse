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

/**
 * Returns true if running in the qunit test harness
 */
export function isTesting() {
  return environment === "qunit-testing";
}

/**
 * Returns true is RAILS_ENV=test (e.g. for system specs)
 */
export function isRailsTesting() {
  return environment === "test";
}

// Generally means "before we migrated to Ember CLI"
export function isLegacyEmber() {
  deprecated("`isLegacyEmber()` is now deprecated and always returns false", {
    id: "discourse.is-legacy-ember",
    dropFrom: "3.0.0.beta1",
  });
  return false;
}

export function isDevelopment() {
  return environment === "development";
}

export function isProduction() {
  return environment === "production";
}
