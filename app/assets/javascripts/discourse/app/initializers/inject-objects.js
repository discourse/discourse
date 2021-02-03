import { setDefaultOwner } from "discourse-common/lib/get-owner";

export default {
  name: "inject-objects",
  initialize(container, app) {
    // This is required for Ember CLI tests to work
    setDefaultOwner(app.__container__);
  },
};
