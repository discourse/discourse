import type { TemplateOnlyComponent } from "@ember/component/template-only";
import type { ComponentLike } from "@glint/template";
import BlockThumbnail from "discourse/blocks/block-thumbnail";
import type { BlockThumbnail as BlockThumbnailValue } from "discourse/blocks/types";
import DefaultBlockThumbnailUntyped from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/default-block-thumbnail";

// TODO(devxp-typescript-pending): drop this cast once default-block-thumbnail is
// authored in .gts with a real Signature, then pass it directly. An untyped .gjs
// component gives Glint no arg/element types, so the core BlockThumbnail's typed
// `@fallback` would otherwise reject it. The runtime import is unchanged.
const DefaultBlockThumbnail =
  DefaultBlockThumbnailUntyped as unknown as ComponentLike<{
    Args: { icon: string };
    Element: HTMLElement;
  }>;

interface PaletteBlockThumbnailSignature {
  Args: {
    /** The block's declared thumbnail, or `null` when it declares none. */
    thumbnail?: BlockThumbnailValue | null;
    /** The block's icon ID, used by the placeholder. */
    icon: string;
  };
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
