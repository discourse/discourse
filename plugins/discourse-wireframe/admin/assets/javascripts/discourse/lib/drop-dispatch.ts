import type {
  InsertBlockArgs,
  MoveBlockArgs,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-block-mutations";
import type {
  GridDropRequest,
  MoveIntoGridCellArgs,
  PlaceInGridCellArgs,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-grid-placement";

/** The complete set of structural commands that can be dispatched on drop. */
export type DropDispatch =
  | {
      /** Inserts a fresh palette block. */
      action: "insertBlock";
      /** Arguments required by the block-insertion command. */
      args: InsertBlockArgs;
    }
  | {
      /** Moves an existing block. */
      action: "moveBlock";
      /** Arguments required by the block-move command. */
      args: MoveBlockArgs;
    }
  | {
      /** Applies the grid drop-rule decision. */
      action: "applyGridDrop";
      /** Grid geometry and source describing the drop. */
      args: GridDropRequest;
    }
  | {
      /** Moves an existing block into a merged-cell placeholder. */
      action: "moveBlockIntoCell";
      /** Existing block and target merged-cell keys. */
      args: MoveIntoGridCellArgs;
    }
  | {
      /** Places a fresh block into a merged-cell placeholder. */
      action: "placeBlockInCell";
      /** Fresh block definition and target merged-cell key. */
      args: PlaceInGridCellArgs;
    };
