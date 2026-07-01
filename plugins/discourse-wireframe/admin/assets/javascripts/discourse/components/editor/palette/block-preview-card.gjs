// @ts-check
/** @type {import("./block-thumbnail.gjs").default} */
import BlockThumbnail from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-thumbnail";

/**
 * Read-only preview shown in the hover tooltip for a palette / inserter tile.
 * Renders the block's thumbnail (delegating to `BlockThumbnail`, which falls
 * back to a framed placeholder carrying the icon) plus the display name and
 * description. The palette row is injected by FloatKit as `@data.entry` (the
 * tile registers this component with `tooltip.register`).
 */
const BlockPreviewCard = <template>
  <div class="wireframe-block-preview">
    <BlockThumbnail
      class="wireframe-block-preview__thumbnail"
      @thumbnail={{@data.entry.thumbnail}}
      @icon={{@data.entry.icon}}
    />
    <span
      class="wireframe-block-preview__name"
    >{{@data.entry.displayName}}</span>
    {{#if @data.entry.description}}
      <span class="wireframe-block-preview__description">
        {{@data.entry.description}}
      </span>
    {{/if}}
  </div>
</template>;

export default BlockPreviewCard;
