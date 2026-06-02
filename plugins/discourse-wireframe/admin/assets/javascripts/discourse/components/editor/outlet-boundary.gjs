// @ts-check

/**
 * Outlet boundary rendered around each `<BlockOutlet>` when the editor is
 * active. Wired via `DEBUG_CALLBACK.OUTLET_INFO_COMPONENT` in the
 * api-initializer.
 *
 * It's an invisible structural marker: the `data-outlet-name` attribute is
 * how `mountedOutletNames()` (`lib/walk-layout.js`) detects which outlets are
 * on the page — which the editor needs before any draft (and thus any root
 * layout) exists. It carries no visual of its own.
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
