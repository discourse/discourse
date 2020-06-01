export const INPUT_DELAY = 250;

let environment = Ember.testing ? "test" : "development";

export function isTesting() {
  return environment === "test";
}

export default { environment };
