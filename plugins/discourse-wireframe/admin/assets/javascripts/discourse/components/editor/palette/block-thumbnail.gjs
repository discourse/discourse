// @ts-check
/** @type {import("discourse/blocks/block-thumbnail.gjs").default} */
import BlockThumbnail from "discourse/blocks/block-thumbnail";
/** @type {import("./default-block-thumbnail.gjs").default} */
import DefaultBlockThumbnail from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/default-block-thumbnail";

/**
 * The palette's thumbnail. A thin wrapper over the core `BlockThumbnail`
 * renderer that supplies the palette's own framed placeholder as the fallback,
 * so a block that declares no thumbnail (or whose lazy thumbnail fails to load)
 * reads as a designed tile rather than a bare icon. All the form handling —
 * inline components, lazy loaders, rasters, the loading skeleton — lives in the
 * core component; this only injects the palette chrome.
 *
 * @param {(string|{light: string, dark?: string}|Function|Object)} [thumbnail]
 *   The block's declared thumbnail.
 * @param {string} icon - The block's icon ID, used by the placeholder.
 */
<template>
  <BlockThumbnail
    @thumbnail={{@thumbnail}}
    @icon={{@icon}}
    @fallback={{DefaultBlockThumbnail}}
    ...attributes
  />
</template>
