// @ts-check

/**
 * Outlet boundary rendered around each `<BlockOutlet>` when the editor is
 * active. Wired via `DEBUG_CALLBACK.OUTLET_INFO_COMPONENT` in the
 * api-initializer.
 *
 * It's an invisible structural marker: the `data-outlet-name` attribute is the
 * DOM anchor used to scroll / jump to a specific outlet (the outline panel and
 * the outlet jump-select). Outlet enumeration no longer reads these — the blocks
 * service's mounted-outlet registry (populated by each `<BlockOutlet>`'s
 * lifecycle) is the source of which outlets are on the page. It carries no
 * visual of its own.
 *
 * The outlet is an implicit layout: its content is normalised to a single
 * root `layout` block, and THAT block's chrome (`.--outlet-root`) carries the
 * outlet's badge + outline and handles selection / drops / the empty state.
 * Keeping the visual on the chrome avoids drawing a second frame and badge
 * around it, and leaves one rendering + selection path.
 */
<template>
  <div class="wireframe-outlet-boundary" data-outlet-name={{@outletName}}>
    {{yield}}
  </div>
</template>
