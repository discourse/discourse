/**
 * Public API block exports.
 *
 * @experimental This API is under active development and may change or be removed
 * in future releases without prior notice. Use with caution in production environments.
 */

// Public API for plugin developers

export { block } from "discourse/lib/blocks/-internals/decorator";
export { BlockCondition } from "discourse/blocks/conditions";
export { defineBlockDataSource } from "discourse/lib/blocks/-internals/data-source";
export {
  registerBlockArgRenderer,
  resetBlockArgRenderer,
} from "discourse/lib/blocks/-internals/arg-renderers";

// Grid-placement readers for container blocks. Surfaced here (not only on
// `discourse/lib/blocks`) so consumers in other bundles can reach them
// through this stable public facade rather than a concrete internal path.
export {
  DEFAULT_GRID_COLUMNS,
  DEFAULT_GRID_ROWS,
  gridDimensions,
  LAYOUT_MERGED_CELL_BLOCK,
  normalizeFractions,
  parsePlacement,
  parseSlotPlacement,
} from "discourse/lib/blocks/-internals/grid-placement";

export { BLOCK_CATEGORIES } from "discourse/blocks/types";

export type {
  ArgSchema,
  ArgType,
  BlockCategory,
  BlockClassNames,
  BlockConstraints,
  BlockMetadata,
  BlockNamespaceType,
  BlockOptions,
  BlockValidateFn,
  ChildArgSchema,
  LayoutEntry,
} from "discourse/blocks/types";
