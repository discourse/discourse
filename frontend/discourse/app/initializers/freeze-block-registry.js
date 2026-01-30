import * as BuiltinBlocks from "discourse/blocks/builtin";
import * as conditions from "discourse/blocks/conditions";
import { _freezeBlockRegistry } from "discourse/lib/blocks/-internals/registry/block";
import {
  _freezeConditionTypeRegistry,
  _registerConditionType,
} from "discourse/lib/blocks/-internals/registry/condition";
import { _freezeOutletRegistry } from "discourse/lib/blocks/-internals/registry/outlet";
import { withPluginApi } from "discourse/lib/plugin-api";

/**
 * Initializes the blocks system by registering built-in blocks and conditions,
 * then freezing all registries.
 *
 * This initializer runs after "discourse-bootstrap" but before "inject-discourse-objects"
 * to ensure:
 * - Built-in blocks are registered before the registry is frozen
 * - Core condition types are registered before the registry is frozen
 * - All registries are frozen before plugins/themes configure layouts
 *
 * Execution order within this initializer:
 * 1. Register built-in blocks via plugin API
 * 2. Register core condition types
 * 3. Freeze block, outlet, and condition type registries
 */
export default {
  name: "freeze-block-registry",
  after: "discourse-bootstrap",
  before: "inject-discourse-objects",

  initialize() {
    // Register built-in blocks
    withPluginApi((api) => {
      for (const BlockClass of Object.values(BuiltinBlocks)) {
        if (typeof BlockClass === "function" && BlockClass.blockName) {
          api.registerBlock(BlockClass);
        }
      }
    });

    // Register core condition types
    for (const exported of Object.values(conditions)) {
      if (
        typeof exported === "function" &&
        exported.prototype instanceof conditions.BlockCondition &&
        exported !== conditions.BlockCondition
      ) {
        _registerConditionType(exported);
      }
    }

    // Freeze all registries to prevent further registrations
    _freezeBlockRegistry();
    _freezeOutletRegistry();
    _freezeConditionTypeRegistry();
  },
};
