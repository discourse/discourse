// @ts-check
import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import { LAYOUT_MERGED_CELL_BLOCK } from "discourse/blocks";
import { registerDragAndDropTarget } from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";
import { resolveLinearDrop } from "discourse/plugins/discourse-wireframe/discourse/lib/linear-drop";

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
 *  - `mode` — `"stack"`, `"row"`, `"cell"`, `"grid"`, `"grid-cell-leaf"`,
 *    or `null`. Drives axis math and registration:
 *      - `"stack"` / `"row"` / `"cell"`: register as a drop target.
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
    const isCell = mode === "cell";
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
    // - For empty cells: there's no inner container, the chrome IS the
    //   drop area.
    //
    // Walk strategy: find any descendant chrome with
    // `[data-wf-block-key]`, climb back up to its
    // `.wireframe-block-chrome-wrapper`, and that wrapper's
    // parent IS the container. Falls back to the chrome itself when
    // there are no descendant blocks (empty container case).
    let containerElement = null;
    const resolveContainer = () => {
      if (isCell) {
        return chromeElement;
      }
      if (containerElement && chromeElement.contains(containerElement)) {
        return containerElement;
      }
      // A block can mark the element whose direct children are the drop
      // candidates with `data-wf-drop-container` — needed when those
      // children sit a level below the chrome (e.g. each wrapped in a slide
      // div), where the first-block-wrapper heuristic below would otherwise
      // lock onto a single child. Scope to a marker that belongs to THIS
      // chrome so a nested container's marker isn't picked up.
      const marked = Array.from(
        chromeElement.querySelectorAll("[data-wf-drop-container]")
      ).find((el) => el.closest(".wireframe-block-chrome") === chromeElement);
      if (marked) {
        containerElement = marked;
        return marked;
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
    // root, so there's no parent to defer to; empty-cell chromes
    // also opt out since the grid owns sibling moves at the parent
    // level.
    const shouldDeferToParent = (input) => {
      // The outlet root (no parent) and cells (the grid owns their sibling
      // moves) never defer — only nested container chromes do. The implicit
      // root layout IS the outlet, so it doesn't defer either: there's no
      // sibling level above it to fall through to, and deferring would leave
      // a dead band along its edges where drops vanish.
      if (
        containerKey == null ||
        isCell ||
        wireframe.isOutletRoot(containerKey)
      ) {
        return false;
      }
      return isInEdgeBand(chromeElement.getBoundingClientRect(), input);
    };

    const descriptorFor = (source, input) => {
      if (isCell) {
        return buildCellChromeDescriptor({
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
        // A marked drop container may pin its own axis (e.g. a horizontal
        // slide track) regardless of the chrome's `mode`-derived default.
        axis: container.dataset?.wfDropAxis || axis,
        source,
      });
    };

    this.#cleanup = registerDragAndDropTarget(chromeElement, () => ({
      accepts: ACCEPTED_KINDS,
      indicator: false,
      canDrop: ({ input }) => !shouldDeferToParent(input),
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
 *      block chrome) and project each wrapper's bounding rect onto
 *      the active axis into a `{ near, far }` segment.
 *   2. Hand the segments and the cursor to `resolveLinearDrop`, the
 *      pure geometry helper. It returns either a `gap` (a boundary
 *      between siblings / at the container edge) or a `middle` (the
 *      middle third of one child).
 *   3. A `gap` → `buildBoundaryDescriptor`. Crucially, the last third
 *      of child `i` and the first third of child `i + 1` resolve to
 *      the SAME boundary, so a single "between A and B" zone replaces
 *      the old separate "after A" / "before B" pair.
 *   4. A `middle` → REPLACE (cell) / INSIDE (container) / nothing
 *      (leaf), by block type.
 *
 * Returns `null` when the source can't legally land (self-drop into
 * an adjacent boundary, cross-outlet rejection, etc.) so the overlay
 * disappears for invalid targets.
 *
 * @returns {Object|null}
 */
export function computeDescriptor({
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

  // Project each child onto the active axis so the pure resolver can
  // decide the landing without re-reading the DOM.
  const segments = children.map((child) => {
    const rect = child.wrapper.getBoundingClientRect();
    return axis === "x"
      ? { near: rect.left, far: rect.right }
      : { near: rect.top, far: rect.bottom };
  });

  const result = resolveLinearDrop(segments, cursor);

  // A container may frame its children with a noun (e.g. "slide"), stamped on
  // the drop container, so the drop message names positions in those terms
  // ("between slides 1 and 2") rather than by the child block's own name.
  const childNoun = container.dataset?.wfChildNoun || null;
  const childNounPlural = container.dataset?.wfChildNounPlural || childNoun;

  if (result.kind === "gap") {
    const before = result.gap > 0 ? children[result.gap - 1] : null;
    const after = result.gap < children.length ? children[result.gap] : null;
    return buildBoundaryDescriptor({
      wireframe,
      container,
      axis,
      before,
      after,
      containerKey,
      outletName,
      source,
      childNoun,
      childNounPlural,
      // 1-based ordinals of the neighbours flanking this gap.
      beforeOrdinal: result.gap,
      afterOrdinal: result.gap + 1,
    });
  }

  // Middle third — INSIDE (container) / REPLACE (cell) / nothing (leaf).
  const child = children[result.index];
  const rect = child.wrapper.getBoundingClientRect();
  const targetKey = child.chrome.getAttribute("data-wf-block-key");
  const blockName = child.chrome.getAttribute("data-wf-block-name");

  if (blockName === LAYOUT_MERGED_CELL_BLOCK) {
    return buildReplaceCellDescriptor({
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
      childNoun,
      ordinal: result.index + 1,
    });
  }
  // Leaf block, middle third — no valid landing. Hide the overlay.
  return null;
}

/**
 * Pure edge-band test: is `input` within `band` pixels of any outer
 * edge of `rect`? When a nested container chrome answers `true`, its
 * `canDrop` returns `false` and the drop falls through to the parent
 * container — that's how a drop near a row's edge lands as a sibling
 * of the row in the enclosing stack.
 *
 * @param {DOMRect} rect
 * @param {{clientX: number, clientY: number}} input
 * @param {number} [band]
 * @returns {boolean}
 */
export function isInEdgeBand(rect, input, band = EDGE_BAND) {
  return (
    input.clientY < rect.top + band ||
    input.clientY > rect.bottom - band ||
    input.clientX < rect.left + band ||
    input.clientX > rect.right - band
  );
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
  const located = wireframe.findEntryAndOutletSync(key);
  if (!located) {
    return false;
  }
  const metadata = wireframe.lookupBlockMetadata?.(located.entry.block);
  return metadata?.isContainer === true;
}

/**
 * Builds the descriptor for a drop at a BOUNDARY between siblings, at
 * the container's start / end, or into an empty container. `before` /
 * `after` are the `{wrapper, chrome}` pairs flanking the boundary;
 * either is `null` at a container edge and both are `null` when the
 * container is empty.
 *
 * The old "after A" and "before B" zones now collapse here: the label
 * names BOTH neighbours ("between A and B"), while the dispatch picks
 * one canonical anchor — they produce an identical final order, so the
 * choice is cosmetic for the mutation but lets the preview read
 * naturally.
 */
function buildBoundaryDescriptor({
  wireframe,
  container,
  axis,
  before,
  after,
  containerKey,
  outletName,
  source,
  childNoun = null,
  childNounPlural = null,
  beforeOrdinal = null,
  afterOrdinal = null,
}) {
  const beforeKey = before?.chrome.getAttribute("data-wf-block-key") ?? null;
  const afterKey = after?.chrome.getAttribute("data-wf-block-key") ?? null;

  // Dropping a block onto a boundary it already occupies (immediately
  // next to itself) is a no-op — hide the overlay rather than offer a
  // self-targeting move.
  if (source.type === "wf-block") {
    const sourceKey = source.data.blockKey;
    if (
      sourceKey != null &&
      (sourceKey === beforeKey || sourceKey === afterKey)
    ) {
      return null;
    }
  }

  // Canonical anchor: prefer "before the trailing neighbour"; fall back
  // to "after the leading neighbour" at the container's end. Both land
  // the block in the same gap.
  const targetKey = afterKey ?? beforeKey;
  const position = afterKey ? "before" : "after";

  const containerRect = container.getBoundingClientRect();
  const geometry = boundaryGeometry({ axis, containerRect, before, after });

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
    label: boundaryLabel({
      wireframe,
      source,
      beforeKey,
      afterKey,
      childNoun,
      childNounPlural,
      beforeOrdinal,
      afterOrdinal,
    }),
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

/**
 * Pixel geometry for a boundary indicator. A real boundary is a 4px
 * line centred in the gap; an empty container paints its whole rect so
 * the (otherwise easy-to-miss) landing is unmistakable.
 */
function boundaryGeometry({ axis, containerRect, before, after }) {
  if (!before && !after) {
    return {
      top: containerRect.top,
      left: containerRect.left,
      width: containerRect.width,
      height: containerRect.height,
    };
  }

  const LINE = 4;
  const center = boundaryCenter(axis, before, after);
  if (axis === "y") {
    return {
      top: center - LINE / 2,
      left: containerRect.left,
      width: containerRect.width,
      height: LINE,
    };
  }
  return {
    top: containerRect.top,
    left: center - LINE / 2,
    width: LINE,
    height: containerRect.height,
  };
}

/**
 * The axis coordinate at which to centre the boundary line: midway
 * through the gap when both neighbours exist, otherwise the lone
 * neighbour's facing edge.
 */
function boundaryCenter(axis, before, after) {
  const farOf = (child) => {
    const rect = child.wrapper.getBoundingClientRect();
    return axis === "x" ? rect.right : rect.bottom;
  };
  const nearOf = (child) => {
    const rect = child.wrapper.getBoundingClientRect();
    return axis === "x" ? rect.left : rect.top;
  };
  if (before && after) {
    return (farOf(before) + nearOf(after)) / 2;
  }
  return after ? nearOf(after) : farOf(before);
}

function buildInsideDescriptor({
  wireframe,
  rect,
  targetKey,
  blockName,
  source,
  childNoun = null,
  ordinal = null,
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
    label: insideLabel({
      wireframe,
      source,
      blockName,
      targetKey,
      childNoun,
      ordinal,
    }),
    dispatch: validity.ok ? insideDispatch({ source, targetKey }) : null,
  };
}

/**
 * Builds the descriptor for a drop directly onto a merged-cell
 * chrome (the chrome IS the drop area; there's no inner
 * container to project onto). An empty cell is always a single
 * REPLACE landing, regardless of where the cursor sits within it.
 *
 * Mirrors `buildReplaceCellDescriptor` (used when a sibling
 * dragover hits a cell child) but reads geometry off the chrome
 * itself, since the modifier is attached to the cell's chrome.
 */
function buildCellChromeDescriptor({
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
    label: cellDropLabel({ wireframe, source }),
    dispatch: cellDropDispatch({ source, targetKey: containerKey }),
  };
}

function buildReplaceCellDescriptor({ wireframe, rect, targetKey, source }) {
  // Cell replace — no validation gate beyond "source isn't the
  // cell itself", since an empty cell's only purpose is to be filled.
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
    label: cellDropLabel({ wireframe, source }),
    dispatch: cellDropDispatch({ source, targetKey }),
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
    // Cross-outlet validation lives in `canDropAt`.
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
    outletName: wireframe.findEntryAndOutletSync(targetKey)?.outletName,
  });
}

/* Label builders — `i18n` keys with interpolations the descriptor
   carries pre-resolved (the overlay just renders the string). */

function boundaryLabel({
  wireframe,
  source,
  beforeKey,
  afterKey,
  childNoun = null,
  childNounPlural = null,
  beforeOrdinal = null,
  afterOrdinal = null,
}) {
  const name = sourceDisplayName(wireframe, source);
  const isPalette = source.type === "wf-palette-block";

  // A noun-framed container ("slide") names the dragged block being placed in
  // a NEW child at a 1-based position ("Add Hero in a new slide between slides
  // 1 and 2"), rather than naming the neighbour blocks.
  if (childNoun) {
    const verb = isPalette
      ? "wireframe.canvas.drop_preview.add_child"
      : "wireframe.canvas.drop_preview.move_child";
    // Interior boundary — "between slides 1 and 2".
    if (beforeKey && afterKey) {
      return translate(`${verb}_between`, {
        name,
        noun: childNoun,
        noun_plural: childNounPlural,
        before: beforeOrdinal,
        after: afterOrdinal,
      });
    }
    // Container start — "before slide 1".
    if (afterKey) {
      return translate(`${verb}_before`, {
        name,
        noun: childNoun,
        ordinal: afterOrdinal,
      });
    }
    // Container end — "after slide N".
    if (beforeKey) {
      return translate(`${verb}_after`, {
        name,
        noun: childNoun,
        ordinal: beforeOrdinal,
      });
    }
    // Empty container — fall through to the generic copy below.
  }

  // Interior boundary — name both neighbours ("between A and B").
  if (beforeKey && afterKey) {
    const key = isPalette
      ? "wireframe.canvas.drop_preview.add_between"
      : "wireframe.canvas.drop_preview.move_between";
    return translate(key, {
      name,
      before: targetDisplayName(wireframe, beforeKey),
      after: targetDisplayName(wireframe, afterKey),
    });
  }
  // Container start — "before <first child>".
  if (afterKey) {
    const key = isPalette
      ? "wireframe.canvas.drop_preview.add_before"
      : "wireframe.canvas.drop_preview.move_before";
    return translate(key, {
      name,
      target: targetDisplayName(wireframe, afterKey),
    });
  }
  // Container end — "after <last child>".
  if (beforeKey) {
    const key = isPalette
      ? "wireframe.canvas.drop_preview.add_after"
      : "wireframe.canvas.drop_preview.move_after";
    return translate(key, {
      name,
      target: targetDisplayName(wireframe, beforeKey),
    });
  }
  // Empty container — no neighbours; fall back to the ambient copy.
  return isPalette
    ? translate("wireframe.canvas.drop_preview.add_here", { name })
    : translate("wireframe.canvas.drop_preview.move_here", { name });
}

function insideLabel({
  wireframe,
  source,
  blockName,
  targetKey,
  childNoun = null,
  ordinal = null,
}) {
  const name = sourceDisplayName(wireframe, source);

  // Nesting into a noun-framed child ("into slide 2") — the dragged block keeps
  // its own name; the target is framed as the noun + 1-based ordinal.
  if (childNoun) {
    const key =
      source.type === "wf-palette-block"
        ? "wireframe.canvas.drop_preview.add_child_inside"
        : "wireframe.canvas.drop_preview.move_child_inside";
    return translate(key, {
      name,
      noun: childNoun,
      ordinal,
    });
  }

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

function cellDropLabel({ wireframe, source }) {
  const name = sourceDisplayName(wireframe, source);
  return source.type === "wf-palette-block"
    ? translate("wireframe.canvas.drop_preview.add_here", { name })
    : translate("wireframe.canvas.drop_preview.move_here", { name });
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

function cellDropDispatch({ source, targetKey }) {
  if (source.type === "wf-palette-block") {
    return {
      action: "placeBlockInCell",
      args: {
        cellKey: targetKey,
        blockName: source.data.blockName,
        defaultArgs: source.data.defaultArgs,
      },
    };
  }
  return {
    action: "moveBlockIntoCell",
    args: {
      sourceKey: source.data.blockKey,
      cellKey: targetKey,
    },
  };
}

/* Display-name helpers — pull the human-readable label out of the
   source / target so the overlay text matches what the palette and
   outline already show for the same blocks. */

function sourceDisplayName(wireframe, source) {
  if (source.type === "wf-palette-block") {
    return (
      wireframe.lookupBlockDisplayName?.(source.data.blockName) ||
      source.data.blockName ||
      "block"
    );
  }
  if (source.type === "wf-block") {
    const located = wireframe.findEntryAndOutletSync(source.data.blockKey);
    if (located?.entry) {
      return decorateWithId(
        wireframe.lookupBlockDisplayName?.(located.entry.block) || "block",
        located.entry.id
      );
    }
  }
  return "block";
}

function targetDisplayName(wireframe, targetKey) {
  const located = wireframe.findEntryAndOutletSync(targetKey);
  if (!located?.entry) {
    return null;
  }
  const name = wireframe.lookupBlockDisplayName?.(located.entry.block);
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
