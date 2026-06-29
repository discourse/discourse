// @ts-check
import { registerDestructor } from "@ember/destroyable";
import { service } from "@ember/service";
import Modifier from "ember-modifier";
import { LAYOUT_MERGED_CELL_BLOCK } from "discourse/blocks";
import { registerDragAndDropAutoScroll } from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import { registerDragAndDropTarget } from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";
import { resolveLinearDrop } from "discourse/plugins/discourse-wireframe/discourse/lib/linear-drop";
import {
  flipPosition,
  isReversedFlexLayout,
} from "discourse/plugins/discourse-wireframe/discourse/lib/reversed-flex";

const ACCEPTED_KINDS = ["wf-block", "wf-palette-block"];

/** Outer-edge band (px) where drops fall through to the parent container. */
const EDGE_BAND = 12;

/**
 * One drop target per layout container. Replaces the per-block
 * `--before` / `--after` / `--inside` strip zones with a single
 * dragover handler that decides where the user's drop would land
 * and claims the slot-insert overlay via `wireframeDragOverlay`. The
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
  @service wireframeDragOverlay;
  @service wireframeDropAuthority;
  @service wireframeLayoutQuery;

  #autoScrollCleanup = null;
  #cleanup = null;
  #releaseDrop = null;

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

    const {
      wireframeLayoutQuery,
      wireframeDragOverlay,
      wireframeDropAuthority,
    } = this;
    const { resolveContainer, shouldDeferToParent, descriptorFor } =
      createContainerDropResolver({
        layoutQuery: wireframeLayoutQuery,
        dropAuthority: wireframeDropAuthority,
        chromeElement,
        containerKey,
        outletName,
        mode,
      });

    // Claim the single overlay slot for this container's drop preview. The
    // descriptor (or `null` over an excluded region) is wrapped as a
    // `slot-insert` affordance; an own-but-blank claim still replaces any stale
    // ancestor claim, since enter/drag fire only on the deepest target.
    const claim = (source, input) => {
      this.#releaseDrop = wireframeDragOverlay.claimSlotInsert(
        descriptorFor(source, input)
      );
    };

    this.#cleanup = registerDragAndDropTarget(chromeElement, () => ({
      accepts: ACCEPTED_KINDS,
      indicator: false,
      canDrop: ({ input }) => !shouldDeferToParent(input),
      onDragEnter: ({ source, location }) => {
        // A container that declares a scroll axis (e.g. a horizontal slide
        // track) auto-scrolls when the cursor nears its edge, so a drag can
        // reach an off-screen child. Registered lazily on first entry — the
        // inner scroll element is resolved and present by drag time — and
        // cleared on detach.
        this.#enableAutoScroll(resolveContainer());
        claim(source, location.current.input);
      },
      onDrag: ({ source, location }) => claim(source, location.current.input),
      onDragLeave: () => this.#releaseDrop?.(),
      onDrop: ({ location }) => {
        // A release over an excluded region (e.g. the nav controls) is not a
        // drop — cleanup runs afterwards, so nothing stale dispatches.
        if (isOverExcludedRegion(chromeElement, location.current.input)) {
          return;
        }
        wireframeDragOverlay.dispatch();
      },
    }));
  }

  /**
   * Registers PDND auto-scroll on a container that declares a scroll axis
   * (`data-wf-drop-axis`), so dragging toward its edge reveals off-screen
   * children. A no-op for containers without an axis (the common stack/cell
   * case) and idempotent — registered at most once per drag, then cleared on
   * detach. PDND auto-scroll only engages while a matching drag is in flight,
   * so leaving it registered for the rest of the drag is harmless.
   *
   * @param {HTMLElement|null} container - The resolved scroll element.
   */
  #enableAutoScroll(container) {
    if (this.#autoScrollCleanup || !container?.dataset?.wfDropAxis) {
      return;
    }
    const axis =
      container.dataset.wfDropAxis === "x" ? "horizontal" : "vertical";
    this.#autoScrollCleanup = registerDragAndDropAutoScroll(() => ({
      types: ACCEPTED_KINDS,
      axis,
      target: "element",
      element: container,
    }));
  }

  #detach() {
    this.#cleanup?.();
    this.#cleanup = null;
    this.#autoScrollCleanup?.();
    this.#autoScrollCleanup = null;
  }
}

/**
 * Builds the geometry helpers a chrome's drop handling needs:
 *
 *   - `resolveContainer()` — the element whose direct children are the
 *     candidate landing sites (also the auto-scroll target).
 *   - `shouldDeferToParent(input)` — whether a near-edge drop should fall
 *     through to the parent container instead of landing here.
 *   - `descriptorFor(source, input)` — the drop descriptor (preview +
 *     dispatch) for the cursor position, or `null` when nothing can land.
 *
 * Shared by the `containerDropTarget` modifier (element block drags) and
 * the block chrome's external file-drop handling (OS image files) so both
 * resolve and place a drop the same way. Stateless across drags apart from
 * a per-resolver cache of the resolved container element.
 *
 * @param {Object} options
 * @param {Object} options.layoutQuery - The layout-query service.
 * @param {Object} options.dropAuthority - The drop-authority service that
 *   decides whether a drop is permitted at a given location.
 * @param {HTMLElement} options.chromeElement - The block chrome element.
 * @param {string|null} options.containerKey - The container's composite key
 *   (`null` for the outlet boundary).
 * @param {string} options.outletName - The outlet the container lives in.
 * @param {string} options.mode - The container drop mode (`"stack"`,
 *   `"row"`, or `"cell"`).
 * @returns {{
 *   resolveContainer: () => HTMLElement,
 *   shouldDeferToParent: (input: Object) => boolean,
 *   descriptorFor: (source: Object, input: Object) => (Object|null),
 * }}
 */
export function createContainerDropResolver({
  layoutQuery,
  dropAuthority,
  chromeElement,
  containerKey,
  outletName,
  mode,
}) {
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
      if (wrapper && chromeElement.contains(wrapper) && wrapper.parentElement) {
        containerElement = wrapper.parentElement;
        return containerElement;
      }
    }
    containerElement = chromeElement;
    return containerElement;
  };

  // Edge-band defer. When this resolver is on a CHROME (not the outlet
  // boundary itself), drops within 12px of any outer edge fall through to
  // the parent container so the user can insert a sibling AT THE PARENT
  // level. Without this, a container chrome (e.g. wf:layout in stack mode
  // at outlet root) consumes EVERY drop over its bbox, leaving no way to
  // reach the outlet boundary's drop logic.
  //
  // Returning `false` from `canDrop` excludes this target from PDND's
  // resolution, which then walks up to the next ancestor target — exactly
  // the "fall through to parent" semantics we want. The outlet boundary
  // (containerKey === null) is the root, so there's no parent to defer to;
  // empty-cell chromes also opt out since the grid owns sibling moves at
  // the parent level.
  const shouldDeferToParent = (input) => {
    // The outlet root (no parent) and cells (the grid owns their sibling
    // moves) never defer — only nested container chromes do. The implicit
    // root layout IS the outlet, so it doesn't defer either: there's no
    // sibling level above it to fall through to, and deferring would leave
    // a dead band along its edges where drops vanish.
    if (
      containerKey == null ||
      isCell ||
      layoutQuery.isOutletRoot(containerKey)
    ) {
      return false;
    }
    return isInEdgeBand(chromeElement.getBoundingClientRect(), input);
  };

  const descriptorFor = (source, input) => {
    if (isOverExcludedRegion(chromeElement, input)) {
      return null;
    }
    if (isCell) {
      return buildCellChromeDescriptor({
        layoutQuery,
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
      layoutQuery,
      dropAuthority,
      container,
      chromeElement,
      input,
      containerKey,
      outletName,
      // A marked drop container may pin its own axis (e.g. a horizontal
      // slide track) regardless of the chrome's `mode`-derived default.
      axis: container.dataset?.wfDropAxis || axis,
      source,
    });
  };

  return { resolveContainer, shouldDeferToParent, descriptorFor };
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
  layoutQuery,
  dropAuthority,
  container,
  chromeElement = null,
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
      // A proxy container's children carry the target block key directly via
      // `data-wf-drop-child-key`, with no nested chrome — e.g. a tab strip
      // whose buttons stand in for the panels they page to. The wrapper itself
      // is the geometry, and the key names the panel a boundary insert lands
      // beside. Otherwise the child wraps a rendered block chrome as usual.
      const proxyKey = wrapper.getAttribute?.("data-wf-drop-child-key");
      if (proxyKey) {
        return { wrapper, key: proxyKey, blockName: null, isProxy: true };
      }
      const chrome = wrapper.querySelector(":scope [data-wf-block-key]");
      return chrome
        ? {
            wrapper,
            key: chrome.getAttribute("data-wf-block-key"),
            blockName: chrome.getAttribute("data-wf-block-name"),
            isProxy: false,
          }
        : null;
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
      layoutQuery,
      dropAuthority,
      container,
      // An empty container's drop fills its whole area; when the marked drop
      // container is a small proxy strip (e.g. a tabs tablist) separate from the
      // visible empty region, paint the indicator over the empty-state call to
      // action instead — its placeholder if present, else the chrome — so it
      // lands where the cursor and the prompt actually are.
      emptyRect:
        children.length === 0 ? emptyContainerRect(chromeElement) : null,
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
  // A proxy child (e.g. a tab in a strip) only accepts a boundary insert: its
  // middle third belongs to the navigation that reveals the target, and a drop
  // INTO the target happens in its visible content, never blind through the
  // proxy. So there's nothing to land here.
  if (child.isProxy) {
    return null;
  }
  const rect = child.wrapper.getBoundingClientRect();
  const targetKey = child.key;
  const blockName = child.blockName;

  if (blockName === LAYOUT_MERGED_CELL_BLOCK) {
    return buildReplaceCellDescriptor({
      layoutQuery,
      rect,
      targetKey,
      blockName,
      source,
    });
  }
  if (childIsContainer(layoutQuery, targetKey)) {
    return buildInsideDescriptor({
      layoutQuery,
      dropAuthority,
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
 * Is `input` over a region the container marked as excluded from drops with
 * `data-wf-drop-exclude` (e.g. a carousel's nav controls, which page the track
 * rather than accept a drop)? When true, the modifier produces no drop preview
 * and a release dispatches nothing.
 *
 * Scoped to markers belonging to THIS chrome (`.closest(".wireframe-block-chrome")`
 * === `chromeElement`) so a nested container's exclusion isn't picked up.
 *
 * @param {HTMLElement} chromeElement
 * @param {{clientX: number, clientY: number}} input
 * @returns {boolean}
 */
export function isOverExcludedRegion(chromeElement, input) {
  return Array.from(chromeElement.querySelectorAll("[data-wf-drop-exclude]"))
    .filter((el) => el.closest(".wireframe-block-chrome") === chromeElement)
    .some((el) => {
      const rect = el.getBoundingClientRect();
      return (
        input.clientX >= rect.left &&
        input.clientX <= rect.right &&
        input.clientY >= rect.top &&
        input.clientY <= rect.bottom
      );
    });
}

/**
 * Returns true when the entry at `key` is a container in the live
 * layout. Reads through the layout-query service so the check honours
 * soft-failures / draft state without DOM peeking.
 */
function childIsContainer(layoutQuery, key) {
  if (!key) {
    return false;
  }
  const located = layoutQuery.findEntryAndOutletSync(key);
  if (!located) {
    return false;
  }
  const metadata = layoutQuery.lookupBlockMetadata?.(located.entry.block);
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
  layoutQuery,
  dropAuthority,
  container,
  emptyRect = null,
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
  const beforeKey = before?.key ?? null;
  const afterKey = after?.key ?? null;

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
  // `before`/`after` are computed from VISUAL DOM order. A reversed flex
  // container renders its children in reverse, so the visual side maps to the
  // opposite persisted side — flip the dispatch position to land in the gap
  // the author actually sees. The label/geometry stay visual (unchanged).
  const visualPosition = afterKey ? "before" : "after";
  const containerArgs =
    layoutQuery.findEntryAndOutletSync(containerKey)?.entry?.args;
  const position = isReversedFlexLayout(containerArgs)
    ? flipPosition(visualPosition)
    : visualPosition;

  const containerRect = container.getBoundingClientRect();
  const geometry = boundaryGeometry({
    axis,
    containerRect,
    emptyRect,
    before,
    after,
  });

  const validity = validateInsert({
    dropAuthority,
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
      layoutQuery,
      source,
      beforeKey,
      afterKey,
      childNoun,
      childNounPlural,
      beforeOrdinal,
      afterOrdinal,
    }),
    // No dispatch when invalid — the coordinator's `dispatch()` no-ops on
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
 * the (otherwise easy-to-miss) landing is unmistakable — over `emptyRect`
 * (the visible empty-state area) when one is supplied, else the container.
 */
function boundaryGeometry({ axis, containerRect, emptyRect, before, after }) {
  if (!before && !after) {
    const rect = emptyRect ?? containerRect;
    return {
      top: rect.top,
      left: rect.left,
      width: rect.width,
      height: rect.height,
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
 * The rect to paint an empty container's drop indicator over: the empty-state
 * call-to-action placeholder when the chrome renders one, else the chrome
 * itself. Used when the marked drop container is a small proxy strip (a tabs
 * tablist) sitting apart from the visible empty region, so the indicator lands
 * where the cursor and the prompt are. Returns `null` without a chrome (e.g. a
 * unit test driving `computeDescriptor` directly), leaving the container rect.
 *
 * @param {HTMLElement|null} chromeElement
 * @returns {DOMRect|null}
 */
function emptyContainerRect(chromeElement) {
  if (!chromeElement) {
    return null;
  }
  const placeholder = Array.from(
    chromeElement.querySelectorAll(".wireframe-empty-drop-placeholder")
  ).find((el) => el.closest(".wireframe-block-chrome") === chromeElement);
  return (placeholder ?? chromeElement).getBoundingClientRect();
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
  layoutQuery,
  dropAuthority,
  rect,
  targetKey,
  blockName,
  source,
  childNoun = null,
  ordinal = null,
}) {
  const validity = validateInsideDrop({
    layoutQuery,
    dropAuthority,
    source,
    targetKey,
  });
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
      layoutQuery,
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
  layoutQuery,
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
    label: cellDropLabel({ layoutQuery, source }),
    dispatch: cellDropDispatch({ source, targetKey: containerKey }),
  };
}

function buildReplaceCellDescriptor({ layoutQuery, rect, targetKey, source }) {
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
    label: cellDropLabel({ layoutQuery, source }),
    dispatch: cellDropDispatch({ source, targetKey }),
  };
}

/* Validation predicates — thin wrappers over the drop-authority leaf's
   `canInsertBlockAt` / `canDropAt` so the modifier doesn't reach
   into the layout itself. */

function validateInsert({ dropAuthority, source, outletName }) {
  if (source.type === "wf-palette-block") {
    return {
      ok: dropAuthority.canInsertBlockAt({
        blockName: source.data.blockName,
        targetOutletName: outletName,
      }),
    };
  }
  if (source.type === "wf-block") {
    if (source.data.blockKey == null) {
      return { ok: false };
    }
    // Cross-outlet validation lives in `canDropAt` (it reads the active drag
    // source from the drag-session leaf).
    return {
      ok: dropAuthority.canDropAt({ targetOutletName: outletName }),
    };
  }
  return { ok: false };
}

function validateInsideDrop({ layoutQuery, dropAuthority, source, targetKey }) {
  // Don't allow dropping a container inside itself.
  if (source.type === "wf-block" && source.data.blockKey === targetKey) {
    return { ok: false };
  }
  return validateInsert({
    dropAuthority,
    source,
    outletName: layoutQuery.findEntryAndOutletSync(targetKey)?.outletName,
  });
}

/* Label builders — `i18n` keys with interpolations the descriptor
   carries pre-resolved (the overlay just renders the string). */

function boundaryLabel({
  layoutQuery,
  source,
  beforeKey,
  afterKey,
  childNoun = null,
  childNounPlural = null,
  beforeOrdinal = null,
  afterOrdinal = null,
}) {
  const name = sourceDisplayName(layoutQuery, source);
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
    // Empty container — "Add Hero in a new tab" (the first child of its kind),
    // rather than the generic "Add Hero here".
    return translate(`${verb}_here`, { name, noun: childNoun });
  }

  // Interior boundary — name both neighbours ("between A and B").
  if (beforeKey && afterKey) {
    const key = isPalette
      ? "wireframe.canvas.drop_preview.add_between"
      : "wireframe.canvas.drop_preview.move_between";
    return translate(key, {
      name,
      before: targetDisplayName(layoutQuery, beforeKey),
      after: targetDisplayName(layoutQuery, afterKey),
    });
  }
  // Container start — "before <first child>".
  if (afterKey) {
    const key = isPalette
      ? "wireframe.canvas.drop_preview.add_before"
      : "wireframe.canvas.drop_preview.move_before";
    return translate(key, {
      name,
      target: targetDisplayName(layoutQuery, afterKey),
    });
  }
  // Container end — "after <last child>".
  if (beforeKey) {
    const key = isPalette
      ? "wireframe.canvas.drop_preview.add_after"
      : "wireframe.canvas.drop_preview.move_after";
    return translate(key, {
      name,
      target: targetDisplayName(layoutQuery, beforeKey),
    });
  }
  // Empty container — no neighbours; fall back to the ambient copy.
  return isPalette
    ? translate("wireframe.canvas.drop_preview.add_here", { name })
    : translate("wireframe.canvas.drop_preview.move_here", { name });
}

function insideLabel({
  layoutQuery,
  source,
  blockName,
  targetKey,
  childNoun = null,
  ordinal = null,
}) {
  const name = sourceDisplayName(layoutQuery, source);

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
    targetDisplayName(layoutQuery, targetKey) || blockName || "container";
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

function cellDropLabel({ layoutQuery, source }) {
  const name = sourceDisplayName(layoutQuery, source);
  return source.type === "wf-palette-block"
    ? translate("wireframe.canvas.drop_preview.add_here", { name })
    : translate("wireframe.canvas.drop_preview.move_here", { name });
}

/* Dispatch payload builders — `wireframe.runDropDispatch` looks up
   `[action]` and calls it with `args` at drop time. */

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

function sourceDisplayName(layoutQuery, source) {
  if (source.type === "wf-palette-block") {
    return (
      layoutQuery.lookupBlockDisplayName?.(source.data.blockName) ||
      source.data.blockName ||
      "block"
    );
  }
  if (source.type === "wf-block") {
    const located = layoutQuery.findEntryAndOutletSync(source.data.blockKey);
    if (located?.entry) {
      return decorateWithId(
        layoutQuery.lookupBlockDisplayName?.(located.entry.block) || "block",
        located.entry.id
      );
    }
  }
  return "block";
}

function targetDisplayName(layoutQuery, targetKey) {
  const located = layoutQuery.findEntryAndOutletSync(targetKey);
  if (!located?.entry) {
    return null;
  }
  const name = layoutQuery.lookupBlockDisplayName?.(located.entry.block);
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
