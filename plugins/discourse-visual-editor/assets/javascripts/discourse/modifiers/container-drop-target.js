// @ts-check
import { modifier } from "ember-modifier";
import { i18n } from "discourse-i18n";
import { entryKey } from "../lib/mutate-layout";

/**
 * One drop target per layout container. Replaces the per-block
 * `--before` / `--after` / `--inside` strip zones with a single
 * dragover handler that decides where the user's drop would land
 * and writes the result to `visualEditor.activeDropPreview`. The
 * mounted `<DropPreview>` paints exactly one indicator off of
 * that — by construction there can never be more than one drop
 * indicator on screen.
 *
 * Args (positional):
 *   1. `visualEditor` — the editor service (state lives there so the
 *      single overlay component can read it).
 *   2. `containerKey` — the layout block's composite key. Used in
 *      dispatch payloads so the service knows which container is
 *      the drop target.
 *   3. `outletName` — the outlet the container lives in. Same.
 *   4. `mode` — `"stack"`, `"row"`, or `"grid"`. Drives axis math.
 *      Grid mode is handled by the existing GridOverlay; this
 *      modifier handles stack / row only.
 *
 * The modifier reads child geometry from the container's DOM
 * children. Each direct child of the container is treated as one
 * candidate landing site; the cursor's axis position projects onto
 * the children's bounding rects to pick a gap (insert) or a
 * middle-third zone (inside / replace / no-op).
 */
export default modifier(
  (chromeElement, [visualEditor, containerKey, outletName, mode]) => {
    if (mode === "grid" || mode == null) {
      // Grids own their own dragover handler (see GridOverlay);
      // leaf blocks (mode === null) never act as drop targets on
      // their own — their parent container handles drops near them.
      return () => {};
    }

    // Grid-positioned leaves: the grid overlay's capture-phase
    // dragover paints the preview; we only need the drop event to
    // delegate dispatch back to the parent grid overlay's existing
    // `applySlotDrop` (the legacy path that knows about
    // swap / shift / replace / occupy variants).
    if (mode === "grid-cell-leaf") {
      function onLeafDrop(event) {
        const source = visualEditor.dragSource;
        if (!source) {
          return;
        }
        event.preventDefault();
        event.stopPropagation();
        const parent = visualEditor._findEntryParent?.(containerKey);
        const gridKey = parent ? entryKey(parent) : null;
        const overlay = gridKey
          ? visualEditor._gridOverlays?.get(gridKey)
          : null;
        if (overlay?.applySlotDrop) {
          overlay.applySlotDrop({ source, fallbackCell: null });
        } else {
          visualEditor.endDrag?.();
        }
      }
      chromeElement.addEventListener("drop", onLeafDrop);
      return () => {
        chromeElement.removeEventListener("drop", onLeafDrop);
      };
    }

    const isSlot = mode === "slot";
    const axis = mode === "row" ? "x" : "y";
    // For a `ve:layout` block-chrome, the actual container DOM (where
    // children render as direct siblings) is the `.ve-layout` div
    // emitted by the layout block — one level deeper than the chrome.
    // For slots, there's no inner container — the chrome IS the drop
    // area. For an outlet boundary (no `.ve-layout` descendant) we
    // fall back to the chrome element itself: its direct children are
    // the top-level block wrappers and a label badge, exactly the
    // shape `computeDescriptor` walks.
    let containerElement = null;
    function resolveContainer() {
      if (isSlot) {
        return chromeElement;
      }
      if (containerElement && chromeElement.contains(containerElement)) {
        return containerElement;
      }
      containerElement =
        chromeElement.querySelector(".ve-layout") ?? chromeElement;
      return containerElement;
    }

    function onDragOver(event) {
      const source = visualEditor.dragSource;
      if (!source) {
        return;
      }
      const container = resolveContainer();
      if (!container) {
        return;
      }
      event.preventDefault();
      // `stopPropagation` so nested containers don't both write to
      // `activeDropPreview` — the deepest container wins (Pragmatic
      // dnd uses the same idiom in its own dDragAndDropTarget).
      event.stopPropagation();
      // Always "move" — the `dDragAndDropSource` modifier hardcodes
      // `effectAllowed = "move"` regardless of source kind. If the
      // target sets `dropEffect = "copy"`, the browser rejects the
      // drop because copy isn't in the allowed set, and the user
      // sees the no-entry cursor with no drop firing.
      event.dataTransfer.dropEffect = "move";

      const descriptor = isSlot
        ? buildSlotChromeDescriptor({
            visualEditor,
            chromeElement,
            containerKey,
            source,
          })
        : computeDescriptor({
            visualEditor,
            container,
            event,
            containerKey,
            outletName,
            axis,
            source,
          });
      if (!descriptor) {
        visualEditor.setActiveDropPreview(null);
        return;
      }
      visualEditor.setActiveDropPreview(descriptor);
    }

    function onDragLeave(event) {
      // Clear only when the pointer truly leaves THIS chrome (not
      // when moving between children inside it). `relatedTarget` is
      // the element the cursor entered next; if it's still inside
      // `chromeElement`, we're not leaving.
      if (event.relatedTarget && chromeElement.contains(event.relatedTarget)) {
        return;
      }
      visualEditor.clearActiveDropPreview();
    }

    function onDrop(event) {
      const source = visualEditor.dragSource;
      if (!source) {
        return;
      }
      event.preventDefault();
      event.stopPropagation();
      visualEditor.dispatchActiveDrop();
    }

    chromeElement.addEventListener("dragover", onDragOver);
    chromeElement.addEventListener("dragleave", onDragLeave);
    chromeElement.addEventListener("drop", onDrop);

    return () => {
      chromeElement.removeEventListener("dragover", onDragOver);
      chromeElement.removeEventListener("dragleave", onDragLeave);
      chromeElement.removeEventListener("drop", onDrop);
    };
  }
);

/**
 * Picks the drop descriptor for the current cursor position inside
 * the container. Algorithm:
 *
 *   1. Walk the container's direct children (each is a rendered
 *      block chrome). Record each child's `getBoundingClientRect()`
 *      along the active axis.
 *   2. Find the index `i` whose child the cursor is INSIDE on the
 *      axis. If cursor sits in a gap between two children, `i`
 *      points at the child after the gap.
 *   3. If inside child `i`:
 *      - First third of the child → INSERT before child[i].
 *      - Last third → INSERT after child[i].
 *      - Middle third + child is a `ve:slot` → REPLACE slot.
 *      - Middle third + child is a container → INSIDE child.
 *      - Middle third + leaf block → no overlay (no valid landing).
 *   4. If in a gap or off the ends, INSERT at that boundary.
 *
 * Returns `null` when the source can't legally land (self-drop,
 * cycle, etc.) so the overlay disappears for invalid targets.
 *
 * @returns {Object|null}
 */
function computeDescriptor({
  visualEditor,
  container,
  event,
  containerKey,
  outletName,
  axis,
  source,
}) {
  // The `.ve-layout` div's direct children are chrome-wrapper divs
  // (one per child block). The actual `data-ve-block-key` is on the
  // inner `.visual-editor-block-chrome` element, but the wrapper is
  // the layout-positioned element we want geometry from.
  const children = Array.from(container.children)
    .map((wrapper) => {
      const chrome = wrapper.querySelector(":scope [data-ve-block-key]");
      return chrome ? { wrapper, chrome } : null;
    })
    .filter(Boolean);
  const cursor = axis === "x" ? event.clientX : event.clientY;

  // Find first child whose far edge is past the cursor. That's the
  // candidate "this child or before it".
  let landingIndex = children.length;
  for (let i = 0; i < children.length; i++) {
    const rect = children[i].wrapper.getBoundingClientRect();
    const far = axis === "x" ? rect.right : rect.bottom;
    if (cursor < far) {
      landingIndex = i;
      break;
    }
  }

  if (landingIndex === children.length) {
    // Cursor past every child → INSERT at the container's end.
    const lastChild =
      children.length > 0 ? children[children.length - 1] : null;
    return buildInsertDescriptor({
      visualEditor,
      container,
      axis,
      side: "end",
      anchorRect: lastChild
        ? lastChild.wrapper.getBoundingClientRect()
        : container.getBoundingClientRect(),
      containerKey,
      outletName,
      source,
      position: "after",
      targetKey: lastChild
        ? lastChild.chrome.getAttribute("data-ve-block-key")
        : null,
    });
  }

  const child = children[landingIndex];
  const rect = child.wrapper.getBoundingClientRect();
  const near = axis === "x" ? rect.left : rect.top;
  const far = axis === "x" ? rect.right : rect.bottom;
  const targetKey = child.chrome.getAttribute("data-ve-block-key");
  const blockName = child.chrome.getAttribute("data-ve-block-name");

  if (cursor < near) {
    // Cursor sits in the gap before this child → INSERT before it.
    return buildInsertDescriptor({
      visualEditor,
      container,
      axis,
      side: "before",
      anchorRect: rect,
      containerKey,
      outletName,
      source,
      position: "before",
      targetKey,
    });
  }

  const size = far - near;
  const offset = cursor - near;
  const third = size / 3;
  if (offset < third) {
    return buildInsertDescriptor({
      visualEditor,
      container,
      axis,
      side: "before",
      anchorRect: rect,
      containerKey,
      outletName,
      source,
      position: "before",
      targetKey,
    });
  }
  if (offset > size - third) {
    return buildInsertDescriptor({
      visualEditor,
      container,
      axis,
      side: "after",
      anchorRect: rect,
      containerKey,
      outletName,
      source,
      position: "after",
      targetKey,
    });
  }

  // Middle third — INSIDE (container) / REPLACE (slot) / nothing (leaf).
  if (blockName === "ve:slot") {
    return buildReplaceSlotDescriptor({
      visualEditor,
      rect,
      targetKey,
      blockName,
      source,
    });
  }
  if (childIsContainer(visualEditor, targetKey)) {
    return buildInsideDescriptor({
      visualEditor,
      rect,
      targetKey,
      blockName,
      source,
    });
  }
  // Leaf block, middle third — no valid landing. Hide the overlay.
  return null;
}

/**
 * Returns true when the entry at `key` is a container in the
 * service's live layout. Reads through the editor service so the
 * check honours soft-failures / draft state without DOM peeking.
 */
function childIsContainer(visualEditor, key) {
  if (!key) {
    return false;
  }
  const located = visualEditor._findEntryAndOutletSync(key);
  if (!located) {
    return false;
  }
  const metadata = visualEditor._lookupBlockMetadata?.(located.entry.block);
  return metadata?.isContainer === true;
}

function buildInsertDescriptor({
  visualEditor,
  container,
  axis,
  side,
  anchorRect,
  containerKey,
  outletName,
  source,
  position,
  targetKey,
}) {
  // 4px line along the gap (axis-orthogonal).
  const LINE = 4;
  const containerRect = container.getBoundingClientRect();
  let geometry;
  if (axis === "y") {
    const y =
      side === "before"
        ? anchorRect.top - LINE / 2
        : anchorRect.bottom - LINE / 2;
    geometry = {
      top: y,
      left: containerRect.left,
      width: containerRect.width,
      height: LINE,
    };
  } else {
    const x =
      side === "before"
        ? anchorRect.left - LINE / 2
        : anchorRect.right - LINE / 2;
    geometry = {
      top: containerRect.top,
      left: x,
      width: LINE,
      height: containerRect.height,
    };
  }

  const validity = validateInsert({
    visualEditor,
    source,
    containerKey,
    outletName,
    targetKey,
  });
  if (!validity.ok) {
    return null;
  }

  return {
    geometry,
    kind: "insert",
    variant: "valid",
    label: insertLabel({ visualEditor, source }),
    dispatch: insertDispatch({
      source,
      targetKey,
      position,
      containerKey,
      outletName,
    }),
  };
}

function buildInsideDescriptor({
  visualEditor,
  rect,
  targetKey,
  blockName,
  source,
}) {
  const validity = validateInsideDrop({ visualEditor, source, targetKey });
  if (!validity.ok) {
    return null;
  }
  return {
    geometry: {
      top: rect.top,
      left: rect.left,
      width: rect.width,
      height: rect.height,
    },
    kind: "inside",
    variant: "valid",
    label: insideLabel({ visualEditor, source, blockName, targetKey }),
    dispatch: insideDispatch({ source, targetKey }),
  };
}

/**
 * Builds the descriptor for a drop directly onto a `ve:slot`
 * chrome (the chrome IS the drop area; there's no inner
 * container to project onto). Slots are always a single REPLACE
 * landing, regardless of where the cursor sits within the chrome.
 *
 * Mirrors `buildReplaceSlotDescriptor` (used when a sibling
 * dragover hits a slot child) but reads geometry off the chrome
 * itself, since the modifier is attached to the slot's chrome.
 */
function buildSlotChromeDescriptor({
  visualEditor,
  chromeElement,
  containerKey,
  source,
}) {
  if (source.kind === "ve-block" && source.data.blockKey === containerKey) {
    return null;
  }
  const rect = chromeElement.getBoundingClientRect();
  return {
    geometry: {
      top: rect.top,
      left: rect.left,
      width: rect.width,
      height: rect.height,
    },
    kind: "replace",
    variant: "valid",
    label: replaceSlotLabel({ visualEditor, source }),
    dispatch: replaceSlotDispatch({ source, targetKey: containerKey }),
  };
}

function buildReplaceSlotDescriptor({ visualEditor, rect, targetKey, source }) {
  // Slot replace — no validation gate beyond "source isn't the
  // slot itself", since the slot's only purpose is to be filled.
  if (source.kind === "ve-block" && source.data.blockKey === targetKey) {
    return null;
  }
  return {
    geometry: {
      top: rect.top,
      left: rect.left,
      width: rect.width,
      height: rect.height,
    },
    kind: "replace",
    variant: "valid",
    label: replaceSlotLabel({ visualEditor, source }),
    dispatch: replaceSlotDispatch({ source, targetKey }),
  };
}

/* Validation predicates — thin wrappers over the service's existing
   `canInsertBlockAt` / `canDropAt` so the modifier doesn't reach
   into the layout itself. */

function validateInsert({ visualEditor, source, outletName }) {
  if (source.kind === "ve-palette-block") {
    return {
      ok: visualEditor.canInsertBlockAt({
        blockName: source.data.blockName,
        targetOutletName: outletName,
      }),
    };
  }
  if (source.kind === "ve-block") {
    if (source.data.blockKey == null) {
      return { ok: false };
    }
    // Cross-outlet validation lives in `canDropAt` — same predicate
    // the old strip zones used.
    return {
      ok: visualEditor.canDropAt
        ? visualEditor.canDropAt({
            sourceKey: source.data.blockKey,
            targetOutletName: outletName,
          })
        : true,
    };
  }
  return { ok: false };
}

function validateInsideDrop({ visualEditor, source, targetKey }) {
  // Don't allow dropping a container inside itself.
  if (source.kind === "ve-block" && source.data.blockKey === targetKey) {
    return { ok: false };
  }
  return validateInsert({
    visualEditor,
    source,
    outletName: visualEditor._findEntryAndOutletSync(targetKey)?.outletName,
  });
}

/* Label builders — `i18n` keys with interpolations the descriptor
   carries pre-resolved (the overlay just renders the string). */

function insertLabel({ visualEditor, source }) {
  const name = sourceDisplayName(visualEditor, source);
  return source.kind === "ve-palette-block"
    ? translate("visual_editor.canvas.drop_preview.add_here", { name })
    : translate("visual_editor.canvas.drop_preview.move_here", { name });
}

function insideLabel({ visualEditor, source, blockName, targetKey }) {
  const name = sourceDisplayName(visualEditor, source);
  const container =
    targetDisplayName(visualEditor, targetKey) || blockName || "container";
  return source.kind === "ve-palette-block"
    ? translate("visual_editor.canvas.drop_preview.add_inside", {
        name,
        container,
      })
    : translate("visual_editor.canvas.drop_preview.move_inside", {
        name,
        container,
      });
}

function replaceSlotLabel({ visualEditor, source }) {
  const name = sourceDisplayName(visualEditor, source);
  return source.kind === "ve-palette-block"
    ? translate("visual_editor.canvas.drop_preview.fill_slot", { name })
    : translate("visual_editor.canvas.drop_preview.move_into_slot", { name });
}

/* Dispatch payload builders — `dispatchActiveDrop` on the service
   looks up `[action]` and calls it with `args`. */

function insertDispatch({
  source,
  targetKey,
  position,
  containerKey,
  outletName,
}) {
  if (source.kind === "ve-palette-block") {
    return {
      action: "insertBlock",
      args: {
        blockName: source.data.blockName,
        defaultArgs: source.data.defaultArgs,
        targetKey: targetKey ?? containerKey,
        position: targetKey ? position : "inside",
        targetOutletName: outletName,
      },
    };
  }
  return {
    action: "moveBlock",
    args: {
      sourceKey: source.data.blockKey,
      targetKey: targetKey ?? containerKey,
      position: targetKey ? position : "inside",
      targetOutletName: outletName,
    },
  };
}

function insideDispatch({ source, targetKey }) {
  if (source.kind === "ve-palette-block") {
    return {
      action: "insertBlock",
      args: {
        blockName: source.data.blockName,
        defaultArgs: source.data.defaultArgs,
        targetKey,
        position: "inside",
      },
    };
  }
  return {
    action: "moveBlock",
    args: {
      sourceKey: source.data.blockKey,
      targetKey,
      position: "inside",
    },
  };
}

function replaceSlotDispatch({ source, targetKey }) {
  if (source.kind === "ve-palette-block") {
    return {
      action: "fillSlot",
      args: {
        slotKey: targetKey,
        blockName: source.data.blockName,
        defaultArgs: source.data.defaultArgs,
      },
    };
  }
  return {
    action: "moveBlockIntoSlot",
    args: {
      sourceKey: source.data.blockKey,
      slotKey: targetKey,
    },
  };
}

/* Display-name helpers — pull the human-readable label out of the
   source / target so the overlay text matches what the palette and
   outline already show for the same blocks. */

function sourceDisplayName(visualEditor, source) {
  if (source.kind === "ve-palette-block") {
    return (
      visualEditor._lookupBlockDisplayName?.(source.data.blockName) ||
      source.data.blockName ||
      "block"
    );
  }
  if (source.kind === "ve-block") {
    const located = visualEditor._findEntryAndOutletSync(source.data.blockKey);
    if (located?.entry) {
      return (
        visualEditor._lookupBlockDisplayName?.(located.entry.block) || "block"
      );
    }
  }
  return "block";
}

function targetDisplayName(visualEditor, targetKey) {
  const located = visualEditor._findEntryAndOutletSync(targetKey);
  if (!located?.entry) {
    return null;
  }
  return visualEditor._lookupBlockDisplayName?.(located.entry.block);
}

function translate(key, vars) {
  return i18n(key, vars);
}
