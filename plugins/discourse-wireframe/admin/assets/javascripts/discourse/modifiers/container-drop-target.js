// @ts-check
import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import { registerDragAndDropTarget } from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

const ACCEPTED_KINDS = ["wf-block", "wf-palette-block"];

/** Outer-edge band (px) where drops fall through to the parent container. */
const EDGE_BAND = 12;

/**
 * One drop target per layout container. Replaces the per-block
 * `--before` / `--after` / `--inside` strip zones with a single
 * dragover handler that decides where the user's drop would land
 * and writes the result to `wireframe.activeDropPreview`. The
 * mounted `<DropPreview>` paints exactly one indicator off of
 * that — by construction there can never be more than one drop
 * indicator on screen.
 *
 * Args (named):
 *  - `containerKey` — the layout block's composite key. Used in
 *    dispatch payloads so the service knows which container is the
 *    drop target. `null` (or omitted) for the outlet boundary.
 *  - `outletName` — the outlet the container lives in.
 *  - `mode` — `"stack"`, `"row"`, `"slot"`, `"grid"`, `"grid-cell-leaf"`,
 *    or `null`. Drives axis math and registration:
 *      - `"stack"` / `"row"` / `"slot"`: register as a drop target.
 *      - `"grid"`: GridOverlay owns the grid div directly; no-op here.
 *      - `"grid-cell-leaf"`: drops on a leaf in a grid cell bubble
 *        up via PDND's "closest ancestor target" resolution to the
 *        grid's drop target; no-op here.
 *      - `null`: leaf in a stack / row container; the parent
 *        container chrome handles drops near it.
 *
 * The modifier reads child geometry from the container's DOM
 * children. Each direct child of the container is treated as one
 * candidate landing site; the cursor's axis position projects onto
 * the children's bounding rects to pick a gap (insert) or a
 * middle-third zone (inside / replace / no-op).
 *
 * Re-registers on `containerKey` / `outletName` / `mode` changes:
 * `mode` is the consequential one (toggles whether to register at
 * all); the others rarely change. `dropTargetForElements` is cheap,
 * so re-registration on rare arg changes is fine.
 */
export default class ContainerDropTargetModifier extends Modifier {
  @service wireframe;

  #cleanup = null;

  constructor(owner, args) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#detach());
  }

  modify(
    chromeElement,
    _positional,
    { containerKey = null, outletName, mode }
  ) {
    this.#detach();

    if (mode === "grid" || mode === "grid-cell-leaf" || mode == null) {
      return;
    }

    const { wireframe } = this;
    const isSlot = mode === "slot";
    const axis = mode === "row" ? "x" : "y";

    // Find the container element where block-chrome-wrappers are
    // direct siblings — that's the geometry `computeDescriptor`
    // projects the cursor onto.
    //
    // - For a `wf:layout` chrome (stack / row mode): the wrappers
    //   live inside the `.wf-layout` div, which is a DIRECT child
    //   of the chrome.
    // - For the outlet boundary: the wrappers live inside
    //   `BlockOutletRootContainer`'s `__layout` div, three levels
    //   below the boundary (boundary → div.outletName →
    //   div.outletName__container → div.outletName__layout →
    //   wrappers). Can't use a hardcoded selector because the
    //   classnames are outlet-specific.
    // - For slots: there's no inner container, the chrome IS the
    //   drop area.
    //
    // Walk strategy: find any descendant chrome with
    // `[data-wf-block-key]`, climb back up to its
    // `.wireframe-block-chrome-wrapper`, and that wrapper's
    // parent IS the container. Falls back to the chrome itself when
    // there are no descendant blocks (empty container case).
    let containerElement = null;
    const resolveContainer = () => {
      if (isSlot) {
        return chromeElement;
      }
      if (containerElement && chromeElement.contains(containerElement)) {
        return containerElement;
      }
      const firstBlock = chromeElement.querySelector("[data-wf-block-key]");
      if (firstBlock) {
        const wrapper = firstBlock.closest(".wireframe-block-chrome-wrapper");
        if (
          wrapper &&
          chromeElement.contains(wrapper) &&
          wrapper.parentElement
        ) {
          containerElement = wrapper.parentElement;
          return containerElement;
        }
      }
      containerElement = chromeElement;
      return containerElement;
    };

    // Edge-band defer. When this modifier instance is on a CHROME
    // (not the outlet boundary itself), drops within 12px of any
    // outer edge fall through to the parent container so the user
    // can insert a sibling AT THE PARENT level. Without this, a
    // container chrome (e.g. wf:layout in stack mode at outlet
    // root) consumes EVERY drop over its bbox, leaving no way to
    // reach the outlet boundary's drop logic.
    //
    // Returning `false` from `canDrop` excludes this target from
    // PDND's resolution, which then walks up to the next ancestor
    // target — exactly the "fall through to parent" semantics we
    // want. The outlet boundary (containerKey === null) is the
    // root, so there's no parent to defer to; slot chromes also
    // opt out since slots are always single-cell inside a grid and
    // the grid owns sibling moves at the parent level.
    const isInEdgeBand = (input) => {
      if (containerKey == null || isSlot) {
        return false;
      }
      const rect = chromeElement.getBoundingClientRect();
      return (
        input.clientY < rect.top + EDGE_BAND ||
        input.clientY > rect.bottom - EDGE_BAND ||
        input.clientX < rect.left + EDGE_BAND ||
        input.clientX > rect.right - EDGE_BAND
      );
    };

    const descriptorFor = (source, input) => {
      if (isSlot) {
        return buildSlotChromeDescriptor({
          wireframe,
          chromeElement,
          containerKey,
          source,
        });
      }
      const container = resolveContainer();
      if (!container) {
        return null;
      }
      return computeDescriptor({
        wireframe,
        container,
        input,
        containerKey,
        outletName,
        axis,
        source,
      });
    };

    this.#cleanup = registerDragAndDropTarget(chromeElement, () => ({
      accepts: ACCEPTED_KINDS,
      indicator: false,
      canDrop: ({ input }) => !isInEdgeBand(input),
      onDragEnter: ({ source, location }) =>
        wireframe.setActiveDropPreview(
          descriptorFor(source, location.current.input)
        ),
      onDrag: ({ source, location }) =>
        wireframe.setActiveDropPreview(
          descriptorFor(source, location.current.input)
        ),
      onDragLeave: () => wireframe.clearActiveDropPreview(),
      onDrop: () => wireframe.dispatchActiveDrop(),
    }));
  }

  #detach() {
    this.#cleanup?.();
    this.#cleanup = null;
  }
}

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
 *      - Middle third + child is a `wf:slot` → REPLACE slot.
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
  wireframe,
  container,
  input,
  containerKey,
  outletName,
  axis,
  source,
}) {
  // The `.wf-layout` div's direct children are chrome-wrapper divs
  // (one per child block). The actual `data-wf-block-key` is on the
  // inner `.wireframe-block-chrome` element, but the wrapper is
  // the layout-positioned element we want geometry from.
  const children = Array.from(container.children)
    .map((wrapper) => {
      const chrome = wrapper.querySelector(":scope [data-wf-block-key]");
      return chrome ? { wrapper, chrome } : null;
    })
    .filter(Boolean);
  const cursor = axis === "x" ? input.clientX : input.clientY;

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
      wireframe,
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
        ? lastChild.chrome.getAttribute("data-wf-block-key")
        : null,
    });
  }

  const child = children[landingIndex];
  const rect = child.wrapper.getBoundingClientRect();
  const near = axis === "x" ? rect.left : rect.top;
  const far = axis === "x" ? rect.right : rect.bottom;
  const targetKey = child.chrome.getAttribute("data-wf-block-key");
  const blockName = child.chrome.getAttribute("data-wf-block-name");

  if (cursor < near) {
    // Cursor sits in the gap before this child → INSERT before it.
    return buildInsertDescriptor({
      wireframe,
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
      wireframe,
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
      wireframe,
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
  if (blockName === "wf:slot") {
    return buildReplaceSlotDescriptor({
      wireframe,
      rect,
      targetKey,
      blockName,
      source,
    });
  }
  if (childIsContainer(wireframe, targetKey)) {
    return buildInsideDescriptor({
      wireframe,
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
function childIsContainer(wireframe, key) {
  if (!key) {
    return false;
  }
  const located = wireframe._findEntryAndOutletSync(key);
  if (!located) {
    return false;
  }
  const metadata = wireframe._lookupBlockMetadata?.(located.entry.block);
  return metadata?.isContainer === true;
}

function buildInsertDescriptor({
  wireframe,
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
  const containerRect = container.getBoundingClientRect();
  let geometry;
  if (!targetKey) {
    // Empty container — no anchor child to draw a line next to. Paint
    // the whole container rect so the user can clearly see WHERE the
    // block will land. A 4px line at the container's edge is easy to
    // miss when the container is tall (or just yellow-tinted, like an
    // empty outlet).
    geometry = {
      top: containerRect.top,
      left: containerRect.left,
      width: containerRect.width,
      height: containerRect.height,
    };
  } else if (axis === "y") {
    // 4px line along the gap (axis-orthogonal).
    const LINE = 4;
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
    const LINE = 4;
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
    wireframe,
    source,
    containerKey,
    outletName,
    targetKey,
  });

  return {
    geometry,
    // Use `inside` for empty containers so the overlay reads as
    // "drop INTO this" rather than "insert at edge". Same visual
    // treatment, but the semantic kind is what the label and any
    // future variant styling key off.
    kind: targetKey ? "insert" : "inside",
    validity: validity.ok ? "valid" : "invalid",
    label: insertLabel({ wireframe, source, position, targetKey }),
    // No dispatch when invalid — `dispatchActiveDrop` no-ops on
    // descriptors without a `dispatch` payload, so the drop quietly
    // fails. The red overlay already communicated the rejection.
    dispatch: validity.ok
      ? insertDispatch({
          source,
          targetKey,
          position,
          containerKey,
          outletName,
        })
      : null,
  };
}

function buildInsideDescriptor({
  wireframe,
  rect,
  targetKey,
  blockName,
  source,
}) {
  const validity = validateInsideDrop({ wireframe, source, targetKey });
  return {
    geometry: {
      top: rect.top,
      left: rect.left,
      width: rect.width,
      height: rect.height,
    },
    kind: "inside",
    validity: validity.ok ? "valid" : "invalid",
    label: insideLabel({ wireframe, source, blockName, targetKey }),
    dispatch: validity.ok ? insideDispatch({ source, targetKey }) : null,
  };
}

/**
 * Builds the descriptor for a drop directly onto a `wf:slot`
 * chrome (the chrome IS the drop area; there's no inner
 * container to project onto). Slots are always a single REPLACE
 * landing, regardless of where the cursor sits within the chrome.
 *
 * Mirrors `buildReplaceSlotDescriptor` (used when a sibling
 * dragover hits a slot child) but reads geometry off the chrome
 * itself, since the modifier is attached to the slot's chrome.
 */
function buildSlotChromeDescriptor({
  wireframe,
  chromeElement,
  containerKey,
  source,
}) {
  if (source.type === "wf-block" && source.data.blockKey === containerKey) {
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
    validity: "valid",
    label: replaceSlotLabel({ wireframe, source }),
    dispatch: replaceSlotDispatch({ source, targetKey: containerKey }),
  };
}

function buildReplaceSlotDescriptor({ wireframe, rect, targetKey, source }) {
  // Slot replace — no validation gate beyond "source isn't the
  // slot itself", since the slot's only purpose is to be filled.
  if (source.type === "wf-block" && source.data.blockKey === targetKey) {
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
    validity: "valid",
    label: replaceSlotLabel({ wireframe, source }),
    dispatch: replaceSlotDispatch({ source, targetKey }),
  };
}

/* Validation predicates — thin wrappers over the service's existing
   `canInsertBlockAt` / `canDropAt` so the modifier doesn't reach
   into the layout itself. */

function validateInsert({ wireframe, source, outletName }) {
  if (source.type === "wf-palette-block") {
    return {
      ok: wireframe.canInsertBlockAt({
        blockName: source.data.blockName,
        targetOutletName: outletName,
      }),
    };
  }
  if (source.type === "wf-block") {
    if (source.data.blockKey == null) {
      return { ok: false };
    }
    // Cross-outlet validation lives in `canDropAt` — same predicate
    // the old strip zones used.
    return {
      ok: wireframe.canDropAt
        ? wireframe.canDropAt({
            sourceKey: source.data.blockKey,
            targetOutletName: outletName,
          })
        : true,
    };
  }
  return { ok: false };
}

function validateInsideDrop({ wireframe, source, targetKey }) {
  // Don't allow dropping a container inside itself.
  if (source.type === "wf-block" && source.data.blockKey === targetKey) {
    return { ok: false };
  }
  return validateInsert({
    wireframe,
    source,
    outletName: wireframe._findEntryAndOutletSync(targetKey)?.outletName,
  });
}

/* Label builders — `i18n` keys with interpolations the descriptor
   carries pre-resolved (the overlay just renders the string). */

function insertLabel({ wireframe, source, position, targetKey }) {
  const name = sourceDisplayName(wireframe, source);
  const target = targetKey ? targetDisplayName(wireframe, targetKey) : null;
  const isPalette = source.type === "wf-palette-block";
  // Empty-container case: no anchor child. Fall back to the
  // ambient "add here / move here" copy.
  if (!target || (position !== "before" && position !== "after")) {
    return isPalette
      ? translate("wireframe.canvas.drop_preview.add_here", { name })
      : translate("wireframe.canvas.drop_preview.move_here", { name });
  }
  const key = isPalette
    ? position === "before"
      ? "wireframe.canvas.drop_preview.add_before"
      : "wireframe.canvas.drop_preview.add_after"
    : position === "before"
      ? "wireframe.canvas.drop_preview.move_before"
      : "wireframe.canvas.drop_preview.move_after";
  return translate(key, { name, target });
}

function insideLabel({ wireframe, source, blockName, targetKey }) {
  const name = sourceDisplayName(wireframe, source);
  const container =
    targetDisplayName(wireframe, targetKey) || blockName || "container";
  return source.type === "wf-palette-block"
    ? translate("wireframe.canvas.drop_preview.add_inside", {
        name,
        container,
      })
    : translate("wireframe.canvas.drop_preview.move_inside", {
        name,
        container,
      });
}

function replaceSlotLabel({ wireframe, source }) {
  const name = sourceDisplayName(wireframe, source);
  return source.type === "wf-palette-block"
    ? translate("wireframe.canvas.drop_preview.fill_slot", { name })
    : translate("wireframe.canvas.drop_preview.move_into_slot", { name });
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
  if (source.type === "wf-palette-block") {
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
  if (source.type === "wf-palette-block") {
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
  if (source.type === "wf-palette-block") {
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

function sourceDisplayName(wireframe, source) {
  if (source.type === "wf-palette-block") {
    return (
      wireframe._lookupBlockDisplayName?.(source.data.blockName) ||
      source.data.blockName ||
      "block"
    );
  }
  if (source.type === "wf-block") {
    const located = wireframe._findEntryAndOutletSync(source.data.blockKey);
    if (located?.entry) {
      return decorateWithId(
        wireframe._lookupBlockDisplayName?.(located.entry.block) || "block",
        located.entry.id
      );
    }
  }
  return "block";
}

function targetDisplayName(wireframe, targetKey) {
  const located = wireframe._findEntryAndOutletSync(targetKey);
  if (!located?.entry) {
    return null;
  }
  const name = wireframe._lookupBlockDisplayName?.(located.entry.block);
  return decorateWithId(name, located.entry.id);
}

/**
 * Appends `#id` to a block's display name when the entry has an
 * author-assigned ID. Matches the `#id` convention the outline
 * panel uses for the same purpose, so labels read consistently
 * across surfaces (e.g. "Heading #hero").
 */
function decorateWithId(name, id) {
  if (!name) {
    return name;
  }
  if (!id) {
    return name;
  }
  return `${name} #${id}`;
}

function translate(key, vars) {
  return i18n(key, vars);
}
