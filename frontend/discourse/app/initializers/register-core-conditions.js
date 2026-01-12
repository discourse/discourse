import * as conditions from "discourse/blocks/conditions";
import { _registerConditionType } from "discourse/lib/blocks/registration";

/**
 * Registers core condition types from the conditions module.
 *
 * This initializer runs after "discourse-bootstrap" but before "freeze-block-registry"
 * to ensure core condition types are available before the registry is frozen.
 */
export default {
  after: "discourse-bootstrap",
  before: "freeze-block-registry",

  initialize() {
    for (const exported of Object.values(conditions)) {
      if (
        typeof exported === "function" &&
        exported.prototype instanceof conditions.BlockCondition &&
        exported !== conditions.BlockCondition
      ) {
        _registerConditionType(exported);
      }
    }
  },
};
