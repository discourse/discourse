import { hash } from "@ember/helper";

const DTapTileGrid = <template>
  <div class="tap-tile-grid" ...attributes>
    {{yield (hash activeTile=@activeTile)}}
  </div>
</template>;

export default DTapTileGrid;
