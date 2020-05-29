import Ember from "ember";

export function reload() {
  if (!Ember.testing) {
    location.reload();
  }
}
