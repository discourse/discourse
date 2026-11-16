import { _freezeValidTransformerNames } from "discourse/lib/transformer";

export default {
  before: "inject-discourse-objects",
  after: "discourse-bootstrap",

  initialize(): void {
    _freezeValidTransformerNames();
  },
};
