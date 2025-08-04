import deprecated from "discourse/lib/deprecated";

export const INPUT_DELAY = 250;

let environment = "unknown";

export function setEnvironment(e) {
  if (isTesting()) {
    environment = "test";
  } else {
    environment = e;
  }
}

/**
 * Returns true if running in the qunit test harness or RAILS_ENV=test (e.g. for system specs)
 */
export function isTesting() {
  return environment === "test";
}

/**
 * Returns true if RAILS_ENV=test (e.g. for system specs)
 */
export function isRailsTesting() {
  deprecated("isRailsTesting is deprecated. Use isTesting instead.", {
    id: "discourse.is-rails-testing",
    since: "3.5.0.beta9-dev",
  });

  return isTesting();
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
