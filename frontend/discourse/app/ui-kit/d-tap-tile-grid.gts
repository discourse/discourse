import type { TOC } from "@ember/component/template-only";
import { hash } from "@ember/helper";
import type { DTapTileId } from "discourse/ui-kit/d-tap-tile";

interface DTapTileGridSignature {
  Args: {
    /** The id of the selected tile. */
    activeTile?: DTapTileId | null;
  };

  Element: HTMLDivElement;

  Blocks: {
    default: [
      /** The grid state to pass to each `DTapTile`. */
      grid: {
        /** The id of the selected tile. */
        activeTile: DTapTileId | null | undefined;
      },
    ];
  };
}

const DTapTileGrid: TOC<DTapTileGridSignature> = <template>
  <div class="tap-tile-grid" ...attributes>
    {{yield (hash activeTile=@activeTile)}}
  </div>
</template>;

export default DTapTileGrid;
