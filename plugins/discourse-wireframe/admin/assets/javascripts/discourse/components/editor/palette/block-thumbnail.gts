import type { TemplateOnlyComponent } from "@ember/component/template-only";
import BlockThumbnail from "discourse/blocks/block-thumbnail";
import type { BlockThumbnail as BlockThumbnailValue } from "discourse/blocks/types";
import DefaultBlockThumbnail from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/default-block-thumbnail";

interface PaletteBlockThumbnailSignature {
  /** Thumbnail value and fallback icon. */
  Args: {
    /** The block's declared thumbnail, or `null` when it declares none. */
    thumbnail?: BlockThumbnailValue | null;
    /** The block's icon ID, used by the placeholder. */
    icon: string;
  };
  /** Root element produced by the delegated thumbnail renderer. */
  Element: HTMLElement;
}

/**
 * The palette's thumbnail. A thin wrapper over the core `BlockThumbnail`
 * renderer that supplies the palette's own framed placeholder as the fallback,
 * so a block that declares no thumbnail (or whose lazy thumbnail fails to load)
 * reads as a designed tile rather than a bare icon. All the form handling —
 * inline components, lazy loaders, rasters, the loading skeleton — lives in the
 * core component; this only injects the palette chrome.
 */
const PaletteBlockThumbnail: TemplateOnlyComponent<PaletteBlockThumbnailSignature> =
  <template>
    <BlockThumbnail
      @thumbnail={{@thumbnail}}
      @icon={{@icon}}
      @fallback={{DefaultBlockThumbnail}}
      ...attributes
    />
  </template>;

export default PaletteBlockThumbnail;
