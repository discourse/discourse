import type { TemplateOnlyComponent } from "@ember/component/template-only";
import BlockThumbnail from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-thumbnail";
import type { BlockPaletteEntry } from "discourse/plugins/discourse-wireframe/discourse/lib/palette";

interface BlockPreviewCardSignature {
  /** FloatKit tooltip payload for the preview card. */
  Args: {
    /**
     * The FloatKit tooltip payload. `entry` is the palette row this preview
     * describes, injected by the tile via `tooltip.register`'s `data` option.
     */
    data: {
      /** Palette entry described by the preview. */
      entry: BlockPaletteEntry;
    };
  };
}

/**
 * Read-only preview shown in the hover tooltip for a palette / inserter tile.
 * Renders the block's thumbnail (delegating to `BlockThumbnail`, which falls
 * back to a framed placeholder carrying the icon) plus the display name and
 * description. The palette row is injected by FloatKit as `@data.entry` (the
 * tile registers this component with `tooltip.register`).
 */
const BlockPreviewCard: TemplateOnlyComponent<BlockPreviewCardSignature> =
  <template>
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
