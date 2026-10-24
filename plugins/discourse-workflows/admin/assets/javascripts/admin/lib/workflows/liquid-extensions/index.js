import { buildLiquidScope } from "../liquid-context.js";
import { buildAutoCloseDelimiters } from "./auto-close-delimiters.js";
import { buildLiquidCompletions } from "./completions.js";
import { buildLiquidDragDrop } from "./drag-drop.js";

export default function buildLiquidExtensions(cmParams, options) {
  // Read per use: the mode is a sibling field, and extensions are built once.
  const { perItem, secondaryInputs } = options;

  const scopes = {
    allItems: buildLiquidScope({ ...options, perItem: false }),
    perItem: buildLiquidScope({ ...options, perItem: true }),
  };
  const scope = () => (perItem() ? scopes.perItem : scopes.allItems);

  return [
    buildAutoCloseDelimiters(cmParams),
    buildLiquidDragDrop(cmParams, { perItem, secondaryInputs }),
    buildLiquidCompletions(cmParams, { scope }),
  ];
}
