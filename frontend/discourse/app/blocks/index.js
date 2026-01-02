/**
 * Public API and core block exports.
 *
 * This module serves two purposes:
 * 1. Public API for plugin/theme developers (block decorator, conditions)
 * 2. Core block components auto-discovered by the Blocks service
 *
 * @module discourse/blocks
 */

// Public API for plugin developers
export { block } from "discourse/components/block-outlet";
export {
  BlockCondition,
  BlockRouteConditionShortcuts,
  raiseBlockValidationError,
} from "discourse/blocks/conditions";

// Core block components (auto-discovered by Blocks service via isBlock check)
export { default as BlockGroup } from "discourse/blocks/block-group";
