import { _freezeValidTransformerNames } from "discourse/lib/transformer";

export default {
  before: "inject-discourse-objects",

  initialize() {
    _freezeValidTransformerNames();
  },
};
