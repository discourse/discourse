// @ts-check
import curryComponent from "ember-curry-component";
import { apiInitializer } from "discourse/lib/api";
import {
  DEBUG_CALLBACK,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import BlockChrome from "../components/editor/block-chrome";
import EntryPill from "../components/editor/entry-pill";
import OutletBoundary from "../components/editor/outlet-boundary";
import EditorShell from "../components/editor/shell";

/**
 * Wires the Phase 1 read-only visual editor:
 *
 *   1. Mounts the floating EntryPill into `after-main-outlet` so permitted
 *      users see an "Edit page" affordance.
 *   2. Mounts the EditorShell (toolbar plus left and right panels) into
 *      `after-main-outlet`. The shell only renders when `isActive` flips on.
 *   3. Installs `BLOCK_DEBUG` and `OUTLET_INFO_COMPONENT` callbacks that
 *      wrap rendered blocks and outlets with the editor's chrome.
 *
 * Phase 1 limitation: dev-tools registers the same debug callbacks lazily
 * (`enableDevTools()`). If a user enables dev-tools after this plugin has
 * already initialised, dev-tools overwrites our callbacks and the editor
 * chrome stops responding until dev-tools is disabled. A proper composition
 * pattern between the two consumers ships in a later phase.
 */
export default apiInitializer((api) => {
  api.renderInOutlet("after-main-outlet", EntryPill);
  api.renderInOutlet("after-main-outlet", EditorShell);

  const editor = api.container.lookup("service:visual-editor");
  installBlockChrome();
  installOutletBoundary(editor);
  installVeThemeAutoEnter(api, editor);
});

/**
 * Reads the `ve_theme` query parameter from the current URL and, when
 * present, auto-enters the editor bound to that theme id. The "Visual
 * Editor" admin button (Phase 3f) navigates here with `?ve_theme=<id>`
 * after the page-picker modal — so the destination page lands with the
 * editor already open against the right theme.
 *
 * Hooks into `api.onPageChange` so navigation between routes (with the
 * param preserved) keeps the editor active. We rerun the read on every
 * page change because the SPA's URL changes don't reload the bundle.
 *
 * @param {import("discourse/lib/plugin-api").default} api
 * @param {import("../services/visual-editor").default} editor
 */
function installVeThemeAutoEnter(api, editor) {
  const tryEnter = (url) => {
    const themeId = readVeThemeParam(url);
    if (themeId == null) {
      return;
    }
    if (editor.isActive && editor.activeThemeId === themeId) {
      return;
    }
    editor.enter({ themeId });
  };
  // Fire once on initial mount in case the page loaded with the param.
  tryEnter(window.location.href);
  api.onPageChange(tryEnter);
}

function readVeThemeParam(url) {
  try {
    const parsed = new URL(url, window.location.origin);
    const raw = parsed.searchParams.get("ve_theme");
    if (raw == null) {
      return null;
    }
    const parsedInt = parseInt(raw, 10);
    return Number.isFinite(parsedInt) && parsedInt > 0 ? parsedInt : null;
  } catch {
    return null;
  }
}

/**
 * Wires `OUTLET_INFO_COMPONENT` so each `<BlockOutlet>` renders our boundary
 * chrome while the editor is active. Falls through to whatever was previously
 * registered (e.g. dev-tools' info component) when the editor is inactive,
 * so nothing breaks for other consumers.
 *
 * @param {import("../services/visual-editor").default} editor
 */
function installOutletBoundary(editor) {
  const previous = debugHooks.getCallback(DEBUG_CALLBACK.OUTLET_INFO_COMPONENT);
  debugHooks.setCallback(DEBUG_CALLBACK.OUTLET_INFO_COMPONENT, () => {
    if (editor.isActive) {
      return OutletBoundary;
    }
    return previous ? previous() : null;
  });
}

/**
 * Wires `BLOCK_DEBUG` to wrap every rendered block with `BlockChrome`. When
 * the editor is inactive the chrome adds no DOM, so we install the wrapper
 * unconditionally and let `BlockChrome` decide at render time whether to
 * paint chrome.
 *
 * The save-and-fall-through pattern (see `previous` below) lets us coexist
 * with any pre-registered callback (e.g. dev-tools' overlay): we run their
 * callback first and wrap whatever component they produced.
 */
function installBlockChrome() {
  const previous = debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG);
  let fallbackKeyCounter = 0;

  debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, (blockData, context) => {
    const upstream = previous ? previous(blockData, context) : blockData;

    // Ghost blocks (failed conditions) already render their own debug
    // visualization. Don't wrap them — selection is for visible blocks.
    if (upstream?.isGhost) {
      return upstream;
    }

    const wrapped = upstream?.Component ?? blockData.Component;
    if (!wrapped) {
      return upstream;
    }

    // Use the layout's stable per-entry key when available (exposed via the
    // BLOCK_DEBUG payload, formatted as `${name}:${__stableKey}`). The
    // outline walker mints the same key, so canvas ↔ outline selection
    // compares apples to apples. The fallback handles ghost-render code
    // paths in `dev-tools` that don't propagate the key.
    const blockKey =
      blockData.key ?? `${blockData.name}@${++fallbackKeyCounter}`;

    const owner = getOwnerWithFallback();

    return {
      ...upstream,
      Component: curryComponent(
        BlockChrome,
        {
          blockName: blockData.name,
          blockId: blockData.id,
          blockKey,
          blockArgs: blockData.args,
          containerArgs: blockData.containerArgs,
          conditions: blockData.conditions,
          outletArgs: context?.outletArgs,
          outletName: context?.outletName,
          WrappedComponent: wrapped,
        },
        owner
      ),
    };
  });
}
