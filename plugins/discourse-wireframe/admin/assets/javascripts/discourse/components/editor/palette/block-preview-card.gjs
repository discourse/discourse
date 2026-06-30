// @ts-check
import dIcon from "discourse/ui-kit/helpers/d-icon";

/**
 * Read-only preview shown in the hover tooltip for a palette / inserter tile.
 * Renders the block's thumbnail image when it declares one, otherwise its icon,
 * plus the display name and description. The palette row is injected by FloatKit
 * as `@data.entry` (the tile registers this component with `tooltip.register`).
 */
const BlockPreviewCard = <template>
  <div class="wireframe-block-preview">
    {{#if @data.entry.thumbnail}}
      <img
        class="wireframe-block-preview__thumbnail"
        src={{@data.entry.thumbnail}}
        aria-hidden="true"
      />
    {{else}}
      <span class="wireframe-block-preview__icon" aria-hidden="true">
        {{dIcon @data.entry.icon}}
      </span>
    {{/if}}
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
