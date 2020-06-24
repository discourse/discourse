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
  return Ember.testing;
}

export function isDevelopment() {
  return environment === "development";
}

export function isProduction() {
  return environment === "production";
}
