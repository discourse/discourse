// @ts-check
import { registerDestructor } from "@ember/destroyable";
import curryComponent from "ember-curry-component";
import { apiInitializer } from "discourse/lib/api";
import {
  DEBUG_CALLBACK,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { FAILURE_TYPE } from "discourse/lib/blocks/-internals/patterns";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { i18n } from "discourse-i18n";
// Absolute addon path because `wf-ghost-block` lives in the universal
// bundle (rendered on live pages when a block fails to resolve), while
// this api-initializer is admin-only. Cross-bundle imports must use
// the absolute `discourse/plugins/<plugin>/discourse/...` form.
import WFGhostBlock from "discourse/plugins/discourse-wireframe/discourse/components/blocks/wf-ghost-block";
import BlockChrome from "../components/editor/block-chrome";
import EntryPill from "../components/editor/entry-pill";
import OutletBoundary from "../components/editor/outlet-boundary";
import EditorShell from "../components/editor/shell";
import { attachEditorShortcuts } from "../lib/editor-shortcuts";

/**
 * Wires the Phase 1 read-only wireframe:
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

  const editor = api.container.lookup("service:wireframe");
  installBlockChrome(editor);
  installGhostChildrenCreator();
  installOutletBoundary(editor);
  installGhostBlocksWhileEditing(editor);
  installEditPresentationWhileEditing(editor);
  installSimulationContext(
    api.container.lookup("service:wireframe-simulation")
  );
  // Instantiate these services at boot so their constructors run before any
  // user interaction: block-reveal/inline-edit/arg-edit subscribe to the
  // selection seam before the first selection change, and image-upload installs
  // its window/document file-drag + paste listeners before the first drag/paste.
  api.container.lookup("service:wireframe-block-reveal");
  api.container.lookup("service:wireframe-inline-edit");
  api.container.lookup("service:wireframe-arg-edit");
  api.container.lookup("service:wireframe-image-upload");
  installVeThemeAutoEnter(api, editor);
  // The editor stays open across SPA navigation, so re-discover the new page's
  // outlets after each transition. `rediscoverOutlets` self-gates on
  // `editor.isActive`, so this is a no-op while the editor is closed.
  api.onPageChange(() => editor.rediscoverOutlets());
  // The shortcut listener self-gates on `editor.isActive`, so we install it
  // once rather than attach/detach on editor enter. Tie its removal to the
  // editor service's teardown: in production that's app shutdown, but in tests
  // — where the initializer boots once per owner — it stops a document
  // `keydown` listener leaking per test. A leaked handler bound to a destroyed
  // editor still fires on later keystrokes and throws when it resolves a
  // service on its dead owner.
  registerDestructor(editor, attachEditorShortcuts(editor));
});

/**
 * Wires the simulation service's slot into the condition evaluator's
 * per-block context via the `EVAL_CONTEXT` debug hook.
 *
 * The callback reads the service's `@tracked` slot on every invocation, so
 * flipping the persona / viewport in the toolbar marks the preprocessor's
 * tracked getter dirty and triggers a re-evaluation across the page.
 * Returning `null` (when no simulation is active) means the evaluator falls
 * back to its real-service reads — no overhead when sim mode is off.
 *
 * Coexists with any pre-existing EVAL_CONTEXT callback by merging the
 * upstream payload with the simulation. Simulation wins on collisions
 * (the user explicitly enabled sim mode).
 *
 * @param {import("../services/wireframe-simulation").default} simulation
 */
function installSimulationContext(simulation) {
  const previous = debugHooks.getCallback(DEBUG_CALLBACK.EVAL_CONTEXT);
  debugHooks.setCallback(DEBUG_CALLBACK.EVAL_CONTEXT, () => {
    const upstream = previous?.() ?? null;
    if (!simulation.isSimulating) {
      return upstream;
    }
    return {
      ...(upstream ?? {}),
      simulation: simulation.value,
    };
  });
}

/**
 * While the editor is active, force the block-rendering pipeline's
 * `showGhosts` flag on so structurally invalid entries (typos in block
 * names, conditions hiding a block) render as labelled placeholders the
 * author can act on instead of disappearing silently. The dev-tools'
 * existing GHOST_BLOCKS callback is preserved via the save-and-OR
 * pattern, so toggling dev-tools off doesn't kill ghost rendering for
 * editor users, and toggling the editor off doesn't kill it for dev-
 * tools users.
 *
 * @param {import("../services/wireframe").default} editor
 */
function installGhostBlocksWhileEditing(editor) {
  const previous = debugHooks.getCallback(DEBUG_CALLBACK.GHOST_BLOCKS);
  debugHooks.setCallback(DEBUG_CALLBACK.GHOST_BLOCKS, () => {
    if (editor.isActive) {
      return true;
    }
    return previous ? previous() : false;
  });
}

/**
 * While the editor is active, force the block pipeline's "edit presentation"
 * flag on so paged / collapsing containers (carousel, tabs, accordion) reveal
 * all of their content at once for direct editing instead of showing one part
 * at a time. Preserves any pre-existing callback via the same save-and-OR
 * pattern as the ghost-blocks installer.
 *
 * @param {import("../services/wireframe").default} editor
 */
function installEditPresentationWhileEditing(editor) {
  const previous = debugHooks.getCallback(DEBUG_CALLBACK.EDIT_PRESENTATION);
  debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, () => {
    if (editor.isActive) {
      return true;
    }
    return previous ? previous() : false;
  });
}

/**
 * Reads the `wf_theme` query parameter from the current URL and, when
 * present, auto-enters the editor bound to that theme id. The
 * "Wireframe" admin button (Phase 3f) navigates here with
 * `?wf_theme=<id>` after the page-picker modal — so the destination
 * page lands with the
 * editor already open against the right theme.
 *
 * Hooks into `api.onPageChange` so navigation between routes (with the
 * param preserved) keeps the editor active. We rerun the read on every
 * page change because the SPA's URL changes don't reload the bundle.
 *
 * @param {import("discourse/lib/plugin-api").default} api
 * @param {import("../services/wireframe").default} editor
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
    const raw = parsed.searchParams.get("wf_theme");
    if (raw == null) {
      return null;
    }
    const parsedInt = parseInt(raw, 10);
    // Any non-zero integer is a valid theme id — core "system" themes
    // (Foundation, Horizon) have negative ids, so don't reject those.
    return Number.isInteger(parsedInt) && parsedInt !== 0 ? parsedInt : null;
  } catch {
    return null;
  }
}

/**
 * Wires `GHOST_CHILDREN_CREATOR` so a container that fails with
 * `NO_VISIBLE_CHILDREN` doesn't render as an empty placeholder — its
 * child entries are recursively turned into ghost components (each
 * routed back through the `BLOCK_DEBUG` hook, so each child gets its
 * own chrome + `WFGhostBlock`). This is what lets authors see and
 * edit nested failing entries (e.g. four broken merged-cell rows
 * inside a failing layout container).
 *
 * Mirrors core's dev-tools `createGhostChildren` (in
 * `static/dev-tools/block-debug/patch.js`) but extends it to handle
 * unresolved (`UNKNOWN_BLOCK`) children — dev-tools' version skips
 * those, which is the exact case authors hit when a saved layout
 * references a renamed / removed block.
 */
function installGhostChildrenCreator() {
  debugHooks.setCallback(
    DEBUG_CALLBACK.GHOST_CHILDREN_CREATOR,
    function wfCreateGhostChildren(
      childEntries,
      _owner,
      containerPath,
      _outletArgs,
      _isLoggingEnabled,
      resolveBlockFn,
      depth = 0
    ) {
      // Defense-in-depth — `validateLayout` enforces a much tighter
      // bound at registration time, but if something slips past we'd
      // rather render an empty ghost than infinite-loop.
      if (depth >= 20) {
        return [];
      }

      const blockDebug = debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG);
      if (!blockDebug) {
        return [];
      }

      const result = [];
      for (const childEntry of childEntries) {
        const resolvedBlock = resolveBlockFn(childEntry.block);

        // Unresolved branch — typo'd / removed block reference.
        // Dev-tools skips these; the editor renders them as
        // selectable `UNKNOWN_BLOCK` ghosts so authors can fix them.
        if (!resolvedBlock) {
          const blockName =
            typeof childEntry.block === "string"
              ? childEntry.block
              : "(unknown)";
          // Mint the same composite key the outline walker uses
          // (`${name}:${__stableKey}`) so canvas ↔ outline selection
          // syncs for ghost children too.
          const blockKey = `${blockName}:${childEntry.__stableKey ?? "no-key"}`;
          // Recurse into the unknown block's children even though the
          // block itself is unresolved. The children are often still
          // valid (e.g. a `wf:button-link` inside a removed `wf:layout`
          // container) — surfacing them keeps the author's work
          // editable, so they can drag the salvageable pieces out
          // before deleting the broken parent.
          let nestedGhostChildren = null;
          if (childEntry.children?.length) {
            nestedGhostChildren = wfCreateGhostChildren(
              childEntry.children,
              _owner,
              `${containerPath}/${blockName}`,
              _outletArgs,
              _isLoggingEnabled,
              resolveBlockFn,
              depth + 1
            );
          }
          const ghostData = blockDebug(
            {
              name: blockName,
              id: childEntry.id,
              key: blockKey,
              Component: null,
              args: childEntry.args,
              containerArgs: childEntry.containerArgs,
              conditions: childEntry.conditions,
              conditionsPassed: false,
              failureType: FAILURE_TYPE.UNKNOWN_BLOCK,
              failureReason: `Block "${blockName}" is not registered.`,
              children: nestedGhostChildren,
            },
            { outletName: containerPath }
          );
          if (ghostData?.Component) {
            result.push({ ...ghostData, key: blockKey });
          }
          continue;
        }

        // Resolved branch — block class exists; the entry is invisible
        // because of its own failed conditions or because its own
        // children all failed. Recurse into nested containers when
        // they're the `NO_VISIBLE_CHILDREN` case so the whole
        // sub-tree surfaces.
        const meta = getBlockMetadata(resolvedBlock);
        const blockName =
          meta?.blockName ??
          (typeof childEntry.block === "string"
            ? childEntry.block
            : "(unknown)");
        const isChildContainer = meta?.isContainer ?? false;

        // A child of an unknown / failing parent has no `__failureType`
        // marker (the framework never preprocesses inside an unrendered
        // parent). Treat those as "orphaned but salvageable" — render
        // them as ghosts with a CONDITION_FAILED failure (neutral
        // styling, not error-red) and a custom reason that nudges
        // the author to drag them elsewhere to recover the work.
        const failureType =
          childEntry.__failureType ?? FAILURE_TYPE.CONDITION_FAILED;
        const failureReason =
          childEntry.__failureReason ??
          (childEntry.__failureType
            ? undefined
            : "Parent block isn't rendering. Drag this elsewhere to recover the work, or remove it.");

        // Recurse into children whenever the entry has them — for
        // NO_VISIBLE_CHILDREN containers (the obvious case) AND for
        // salvageable orphans whose original parent is unknown, so
        // their grandchildren stay reachable too.
        let nestedGhostChildren = null;
        if (isChildContainer && childEntry.children?.length) {
          nestedGhostChildren = wfCreateGhostChildren(
            childEntry.children,
            _owner,
            `${containerPath}/${blockName}`,
            _outletArgs,
            _isLoggingEnabled,
            resolveBlockFn,
            depth + 1
          );
        }

        const blockKey = `${blockName}:${childEntry.__stableKey ?? "no-key"}`;
        const ghostData = blockDebug(
          {
            name: blockName,
            id: childEntry.id,
            key: blockKey,
            Component: null,
            args: childEntry.args,
            containerArgs: childEntry.containerArgs,
            conditions: childEntry.conditions,
            conditionsPassed: false,
            failureType,
            failureReason,
            children: nestedGhostChildren,
          },
          { outletName: containerPath }
        );
        if (ghostData?.Component) {
          result.push({ ...ghostData, key: blockKey });
        }
      }
      return result;
    }
  );
}

/**
 * Wires `OUTLET_INFO_COMPONENT` so each `<BlockOutlet>` renders our boundary
 * chrome while the editor is active. Falls through to whatever was previously
 * registered (e.g. dev-tools' info component) when the editor is inactive,
 * so nothing breaks for other consumers.
 *
 * @param {import("../services/wireframe").default} editor
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
function installBlockChrome(editor) {
  const previous = debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG);
  let fallbackKeyCounter = 0;

  debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, (blockData, context) => {
    const upstream = previous ? previous(blockData, context) : blockData;
    // A ghost call is signalled by EITHER an upstream `isGhost: true`
    // (set by dev-tools when both plugins coexist) OR a `failureType`
    // on the raw `blockData` (set by core's `createDebugGhost` /
    // `handleUnknownBlock` regardless of whether dev-tools is loaded).
    // The latter is what lets us paint ghosts in editor-only sessions —
    // without it, `Component: null` would bail out at the wrap guard
    // below and the failing entry would disappear from the canvas.
    const isGhost = !!upstream?.isGhost || !!blockData.failureType;

    const owner = getOwnerWithFallback();

    // Use the layout's stable per-entry key when available (exposed via the
    // BLOCK_DEBUG payload, formatted as `${name}:${__stableKey}`). The
    // outline walker mints the same key, so canvas ↔ outline selection
    // compares apples to apples. The fallback handles ghost-render code
    // paths in `dev-tools` that don't propagate the key.
    const blockKey =
      blockData.key ?? `${blockData.name}@${++fallbackKeyCounter}`;

    // The outlet's implicit root layout IS the outlet — when it fails because
    // every block inside is hidden / invalid, the ghost should read as the
    // outlet (its name, an outlet-appropriate hint) rather than a generic
    // "container". Nested / real layout ghosts are untouched (they aren't the
    // recorded outlet root).
    const isOutletRootGhost =
      isGhost &&
      blockData.failureType === FAILURE_TYPE.NO_VISIBLE_CHILDREN &&
      editor.layoutQuery.isOutletRoot(blockKey);
    const ghostName = isOutletRootGhost
      ? (context?.rootOutletName ?? context?.outletName)
      : blockData.name;
    const ghostReason = isOutletRootGhost
      ? i18n("wireframe.canvas.ghost.outlet_no_visible_children")
      : blockData.failureReason;

    // Pick the inner component the chrome will wrap:
    //   - real blocks: the curried block component the upstream / blockData
    //     payload already supplies.
    //   - ghost blocks: `WFGhostBlock` curried with the entry's failure
    //     metadata. We curry up-front because `BlockChrome` invokes its
    //     `<@WrappedComponent />` with no args, so anything the ghost
    //     component needs (block name, failureType, reason) has to be
    //     baked into the component itself.
    const wrapped = isGhost
      ? curryComponent(
          WFGhostBlock,
          {
            blockName: ghostName,
            blockId: blockData.id,
            failureType: blockData.failureType,
            failureReason: ghostReason,
            // When the parent ghost's children were resolved via
            // `GHOST_CHILDREN_CREATOR` (see `installGhostChildrenCreator`
            // below) they arrive as an array of `{Component, key}` ghost
            // descriptors. Forward them so `WFGhostBlock` can render
            // them inside its own silhouette — that's how nested
            // failing entries (e.g. unknown merged-cell rows inside a
            // failing layout) surface as separately editable rows.
            ghostChildren: blockData.children ?? null,
          },
          owner
        )
      : (upstream?.Component ?? blockData.Component);
    if (!wrapped) {
      return upstream;
    }

    return {
      ...upstream,
      // Don't propagate `isGhost: true` upstream — the chrome wraps both
      // real blocks and ghost-as-WFGhostBlock identically. Returning
      // `isGhost: true` would make any further BLOCK_DEBUG consumer
      // (e.g. dev-tools) short-circuit the wrap.
      isGhost: false,
      Component: curryComponent(
        BlockChrome,
        {
          blockName: blockData.name,
          blockId: blockData.id,
          blockKey,
          blockArgs: blockData.args,
          containerArgs: blockData.containerArgs,
          conditions: blockData.conditions,
          // Surfaces the live child count so container chrome can render a
          // visible "Drag a block here" hint when the container is empty —
          // otherwise empty containers collapse to zero height and authors
          // can't see (or aim at) the inside-drop target.
          childCount: blockData.children?.length ?? 0,
          outletArgs: context?.outletArgs,
          // `context.outletName` is the displayHierarchy (a path like
          // `"homepage-blocks/section-1(#hero)"`) — useful for showing
          // the block's location in dev tools, but NOT what the layout
          // registry indexes by. For move operations we need the
          // registry-level outlet (`rootOutletName`); fall back to
          // `outletName` so top-level blocks still work if a stack has
          // an older block-outlet that doesn't supply the new field.
          outletName: context?.rootOutletName ?? context?.outletName,
          displayHierarchy: context?.outletName,
          WrappedComponent: wrapped,
          // Ghost-specific args read by `WFGhostBlock` and by the chrome
          // (to suppress drop zones / resize handle / overlay).
          isGhost,
          // `isError` reserves the danger-tone treatment for genuine
          // authoring mistakes (an UNKNOWN_BLOCK ghost). Condition-failed
          // and no-visible-children ghosts stay neutral — those aren't
          // errors so much as expected outcomes of the layout's gating.
          isError: blockData.failureType === FAILURE_TYPE.UNKNOWN_BLOCK,
          failureType: blockData.failureType,
          failureReason: blockData.failureReason,
        },
        owner
      ),
    };
  });
}
