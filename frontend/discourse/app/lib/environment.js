import { isTesting as embroiderIsTesting } from "@embroider/macros";

export const INPUT_DELAY = 250;

let environment =
  document.getElementById("data-discourse-setup")?.dataset.environment ||
  "unknown";

export function setEnvironment(e) {
  environment = e;
}

/**
 * Returns true if running in the qunit test harness
 */
export function isTesting() {
  return embroiderIsTesting();
}

/**
 * Returns true is RAILS_ENV=test (e.g. for system specs)
 */
export function isRailsTesting() {
  return environment === "test";
}

export function isDevelopment() {
  return environment === "development";
}

export function isProduction() {
  return environment === "production";
}
