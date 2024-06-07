import { _freezeValidTransformerNames } from "discourse/lib/plugin-api/transformer";

export default {
  before: "inject-discourse-objects",

  initialize() {
    _freezeValidTransformerNames();
  },
};
