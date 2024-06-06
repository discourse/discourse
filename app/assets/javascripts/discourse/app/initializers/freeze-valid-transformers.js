import { _freezeValidTransformerNames } from "discourse/lib/plugin-api/value-transformer";

export default {
  before: "inject-discourse-objects",

  initialize() {
    _freezeValidTransformerNames();
  },
};
