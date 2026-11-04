import { setDefaultOwner } from "discourse/lib/get-owner";

export default {
  after: "sniff-capabilities",

  initialize(owner) {
    // This is required for Ember CLI tests to work
    setDefaultOwner(owner.__container__);

    window.Discourse = owner;
  },

  teardown() {
    delete window.Discourse;
  },
};
