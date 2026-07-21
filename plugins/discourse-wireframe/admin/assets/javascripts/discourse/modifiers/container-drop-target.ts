import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import Modifier, { type ArgsFor } from "ember-modifier";
import { LAYOUT_MERGED_CELL_BLOCK } from "discourse/blocks";
import { registerDragAndDropAutoScroll } from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import { registerDragAndDropTarget } from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";
import {
  flipPosition,
  isReversedFlexLayout,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/reversed-flex";
import { resolveLinearDrop } from "discourse/plugins/discourse-wireframe/discourse/lib/linear-drop";
import {
  Indicator,
  resolveWrappingFlowDrop,
  WrappingFlowDropResult,
} from "discourse/plugins/discourse-wireframe/discourse/lib/wrapping-flow-drop";
import type WireframeDragOverlay from "../services/wireframe-drag-overlay";
import type WireframeDropAuthority from "../services/wireframe-drop-authority";
import type WireframeLayoutQuery from "../services/wireframe-layout-query";

/**
 * The container drop modes the modifier understands. `null` marks a leaf block
 * whose parent chrome handles nearby drops.
 */
export type ContainerMode =
  | "stack"
  | "row"
  | "tiles"
  | "cell"
  | "grid"
  | "grid-cell-leaf"
  | null;

/** The cursor position, projected from a drag's pointer input. */
export interface PointerInput {
  clientX: number;
  clientY: number;
}

/**
 * The normalised drag payload surfaced through the ui-kit drop-target helper.
 * That helper is untyped today (its args closure is read as `any`), so the
 * modifier declares the shape it actually reads off a source: a moved block
 * carries its own key, a palette entry carries the block name / default args to
 * insert.
 */
export type DragSource =
  | { type: "wf-block"; data: { blockKey: string | null } }
  | {
      type: "wf-palette-block";
      data: { blockName: string; defaultArgs?: object };
    };

/** A layout mutation the coordinator runs at drop time. */
export interface DropDispatch {
  action: string;
  args: object;
}

/** Viewport-relative pixel rect for the slot-insert indicator. */
export interface DropGeometry {
  top: number;
  left: number;
  width: number;
  height: number;
}

/**
 * The raw descriptor the resolvers produce and hand to the drag-overlay
 * coordinator's `claimSlotInsert`. Structurally the coordinator's
 * `SlotDropDescriptor`.
 */
export interface DropDescriptor {
  geometry: DropGeometry;
  kind: string;
  validity: "valid" | "invalid";
  label: string;
  dispatch: DropDispatch | null;
}

const ACCEPTED_KINDS = ["wf-block", "wf-palette-block"];

/** Outer-edge band (px) where drops fall through to the parent container. */
const EDGE_BAND = 12;

/** The PDND drop location the target callbacks receive. */
interface DropLocation {
  current: { input: PointerInput };
}

/** The event object a drop-target enter / drag callback receives. */
interface DragTargetEvent {
  source: DragSource;
  location: DropLocation;
}

interface ContainerDropTargetSignature {
  Element: HTMLElement;
  Args: {
    Named: {
      containerKey?: string | null;
      outletName: string;
      mode: ContainerMode;
    };
    Positional: [];
  };
}

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
export default class ContainerDropTargetModifier extends Modifier<ContainerDropTargetSignature> {
  @service declare wireframeDragOverlay: WireframeDragOverlay;
  @service declare wireframeDropAuthority: WireframeDropAuthority;
  @service declare wireframeLayoutQuery: WireframeLayoutQuery;

  #autoScrollCleanup: (() => void) | null = null;
  #cleanup: (() => void) | null = null;
  #releaseDrop: (() => void) | null = null;

  constructor(owner: Owner, args: ArgsFor<ContainerDropTargetSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#detach());
  }

  modify(
    chromeElement: HTMLElement,
    _positional: [],
    {
      containerKey = null,
      outletName,
      mode,
    }: ContainerDropTargetSignature["Args"]["Named"]
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
    const claim = (source: DragSource, input: PointerInput) => {
      this.#releaseDrop = wireframeDragOverlay.claimSlotInsert(
        descriptorFor(source, input)
      );
    };

    this.#cleanup = registerDragAndDropTarget(chromeElement, () => ({
      accepts: ACCEPTED_KINDS,
      indicator: false,
      canDrop: ({ input }: { input: PointerInput }) =>
        !shouldDeferToParent(input),
      onDragEnter: ({ source, location }: DragTargetEvent) => {
        // A container that declares a scroll axis (e.g. a horizontal slide
        // track) auto-scrolls when the cursor nears its edge, so a drag can
        // reach an off-screen child. Registered lazily on first entry — the
        // inner scroll element is resolved and present by drag time — and
        // cleared on detach.
        this.#enableAutoScroll(resolveContainer());
        claim(source, location.current.input);
      },
      onDrag: ({ source, location }: DragTargetEvent) =>
        claim(source, location.current.input),
      onDragLeave: () => this.#releaseDrop?.(),
      onDrop: ({ location }: { location: DropLocation }) => {
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
   * @param container - The resolved scroll element.
   */
  #enableAutoScroll(container: HTMLElement | null) {
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

/** Options accepted by {@link createContainerDropResolver}. */
export interface ContainerDropResolverOptions {
  layoutQuery: WireframeLayoutQuery;
  dropAuthority: WireframeDropAuthority;
  chromeElement: HTMLElement;
  containerKey: string | null;
  outletName: string;
  mode: ContainerMode;
}

/** The geometry helpers a chrome's drop handling needs. */
export interface ContainerDropResolver {
  resolveContainer: () => HTMLElement;
  shouldDeferToParent: (input: PointerInput) => boolean;
  descriptorFor: (
    source: DragSource,
    input: PointerInput
  ) => DropDescriptor | null;
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
 */
export function createContainerDropResolver({
  layoutQuery,
  dropAuthority,
  chromeElement,
  containerKey,
  outletName,
  mode,
}: ContainerDropResolverOptions): ContainerDropResolver {
  const isCell = mode === "cell";
  // Row and tiles are horizontal flows (x); stack and cell are vertical (y).
  // A horizontal flow may wrap onto multiple lines, so its descriptor uses the
  // wrap-aware resolver (see `computeDescriptor`).
  const axis: "x" | "y" = mode === "row" || mode === "tiles" ? "x" : "y";

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
  let containerElement: HTMLElement | null = null;
  const resolveContainer = (): HTMLElement => {
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
      chromeElement.querySelectorAll<HTMLElement>("[data-wf-drop-container]")
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
  const shouldDeferToParent = (input: PointerInput): boolean => {
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

  const descriptorFor = (
    source: DragSource,
    input: PointerInput
  ): DropDescriptor | null => {
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
      axis: (container.dataset?.wfDropAxis || axis) as "x" | "y",
      source,
    });
  };

  return { resolveContainer, shouldDeferToParent, descriptorFor };
}

// One candidate landing site inside a container: the layout-positioned wrapper
// element plus the block key and name of the child it stands for. `key` /
// `blockName` come off DOM attributes, so they may be absent.
interface ChildCandidate {
  wrapper: Element;
  key: string | null;
  blockName: string | null;
  isProxy: boolean;
}

/** Options accepted by {@link computeDescriptor}. */
export interface ComputeDescriptorOptions {
  layoutQuery: WireframeLayoutQuery;
  dropAuthority: WireframeDropAuthority;
  container: HTMLElement;
  chromeElement?: HTMLElement | null;
  input: PointerInput;
  containerKey: string | null;
  outletName: string;
  axis: "x" | "y";
  source: DragSource;
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
}: ComputeDescriptorOptions): DropDescriptor | null {
  // The `.wf-layout` div's direct children are chrome-wrapper divs
  // (one per child block). The actual `data-wf-block-key` is on the
  // inner `.wireframe-block-chrome` element, but the wrapper is
  // the layout-positioned element we want geometry from.
  const children = Array.from(container.children)
    .map((wrapper): ChildCandidate | null => {
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
    .filter((child): child is ChildCandidate => Boolean(child));
  // A horizontal flow (row / tiles) may wrap onto multiple visual lines, so it
  // uses the wrap-aware resolver — which groups the children into lines, picks
  // the line under the cursor, and delegates within the line to
  // `resolveLinearDrop`. When the container isn't wrapped it collapses to a
  // single line, i.e. exactly the 1-D result. A vertical flow (stack / cell)
  // never wraps, so it stays on the plain 1-D resolver.
  let result: WrappingFlowDropResult;
  if (axis === "x") {
    const rects = children.map((child) =>
      child.wrapper.getBoundingClientRect()
    );
    result = resolveWrappingFlowDrop(rects, {
      x: input.clientX,
      y: input.clientY,
    });
  } else {
    const segments = children.map((child) => {
      const rect = child.wrapper.getBoundingClientRect();
      return { near: rect.top, far: rect.bottom };
    });
    result = resolveLinearDrop(segments, input.clientY);
  }

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
      // Present only for a wrapped horizontal flow: paints the boundary tick
      // within the target line rather than across the whole container.
      indicator: result.indicator ?? null,
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
 */
export function isInEdgeBand(
  rect: DOMRect,
  input: PointerInput,
  band = EDGE_BAND
): boolean {
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
 */
export function isOverExcludedRegion(
  chromeElement: HTMLElement,
  input: PointerInput
): boolean {
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
function childIsContainer(
  layoutQuery: WireframeLayoutQuery,
  key: string | null
): boolean {
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

interface ValidationResult {
  ok: boolean;
}

interface BoundaryDescriptorOptions {
  layoutQuery: WireframeLayoutQuery;
  dropAuthority: WireframeDropAuthority;
  container: HTMLElement;
  emptyRect?: DOMRect | null;
  axis: "x" | "y";
  indicator?: Indicator | null;
  before: ChildCandidate | null;
  after: ChildCandidate | null;
  containerKey: string | null;
  outletName: string;
  source: DragSource;
  childNoun?: string | null;
  childNounPlural?: string | null;
  beforeOrdinal?: number | null;
  afterOrdinal?: number | null;
}

/**
 * Builds the descriptor for a drop at a BOUNDARY between siblings, at
 * the container's start / end, or into an empty container. `before` /
 * `after` are the child candidates flanking the boundary; either is
 * `null` at a container edge and both are `null` when the container is
 * empty.
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
  indicator = null,
  before,
  after,
  containerKey,
  outletName,
  source,
  childNoun = null,
  childNounPlural = null,
  beforeOrdinal = null,
  afterOrdinal = null,
}: BoundaryDescriptorOptions): DropDescriptor | null {
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
    containerKey == null
      ? undefined
      : layoutQuery.findEntryAndOutletSync(containerKey)?.entry?.args;
  const position = isReversedFlexLayout(containerArgs)
    ? flipPosition(visualPosition)
    : visualPosition;

  const containerRect = container.getBoundingClientRect();
  const geometry = boundaryGeometry({
    axis,
    containerRect,
    emptyRect,
    indicator,
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

interface BoundaryGeometryOptions {
  axis: "x" | "y";
  containerRect: DOMRect;
  emptyRect: DOMRect | null;
  indicator: Indicator | null;
  before: ChildCandidate | null;
  after: ChildCandidate | null;
}

/**
 * Pixel geometry for a boundary indicator. A real boundary is a 4px
 * line centred in the gap; an empty container paints its whole rect so
 * the (otherwise easy-to-miss) landing is unmistakable — over `emptyRect`
 * (the visible empty-state area) when one is supplied, else the container.
 */
function boundaryGeometry({
  axis,
  containerRect,
  emptyRect,
  indicator,
  before,
  after,
}: BoundaryGeometryOptions): DropGeometry {
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

  // A wrapped horizontal flow supplies its own tick geometry: a vertical line
  // confined to the target line's vertical extent (rather than the whole
  // container), centred on the resolved in-line boundary.
  if (indicator) {
    return {
      top: indicator.top,
      left: indicator.x - LINE / 2,
      width: LINE,
      height: indicator.bottom - indicator.top,
    };
  }

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
 */
function emptyContainerRect(chromeElement: HTMLElement | null): DOMRect | null {
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
function boundaryCenter(
  axis: "x" | "y",
  before: ChildCandidate | null,
  after: ChildCandidate | null
): number {
  const farOf = (child: ChildCandidate) => {
    const rect = child.wrapper.getBoundingClientRect();
    return axis === "x" ? rect.right : rect.bottom;
  };
  const nearOf = (child: ChildCandidate) => {
    const rect = child.wrapper.getBoundingClientRect();
    return axis === "x" ? rect.left : rect.top;
  };
  if (before && after) {
    return (farOf(before) + nearOf(after)) / 2;
  }
  // Reached only with exactly one neighbour (`boundaryGeometry` returns early
  // when both are absent), so the non-`after` branch always has a `before`.
  return after ? nearOf(after) : farOf(before as ChildCandidate);
}

interface InsideDescriptorOptions {
  layoutQuery: WireframeLayoutQuery;
  dropAuthority: WireframeDropAuthority;
  rect: DOMRect;
  targetKey: string | null;
  blockName: string | null;
  source: DragSource;
  childNoun?: string | null;
  ordinal?: number | null;
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
}: InsideDescriptorOptions): DropDescriptor {
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

interface CellChromeDescriptorOptions {
  layoutQuery: WireframeLayoutQuery;
  chromeElement: HTMLElement;
  containerKey: string | null;
  source: DragSource;
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
}: CellChromeDescriptorOptions): DropDescriptor | null {
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

interface ReplaceCellDescriptorOptions {
  layoutQuery: WireframeLayoutQuery;
  rect: DOMRect;
  targetKey: string | null;
  // Accepted for call-site symmetry with the INSIDE path; the cell replace
  // needs no block name.
  blockName?: string | null;
  source: DragSource;
}

function buildReplaceCellDescriptor({
  layoutQuery,
  rect,
  targetKey,
  source,
}: ReplaceCellDescriptorOptions): DropDescriptor | null {
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

interface ValidateInsertOptions {
  dropAuthority: WireframeDropAuthority;
  source: DragSource;
  outletName?: string;
  // Accepted from the boundary call site for symmetry; not read here.
  containerKey?: string | null;
  targetKey?: string | null;
}

function validateInsert({
  dropAuthority,
  source,
  outletName,
}: ValidateInsertOptions): ValidationResult {
  if (source.type === "wf-palette-block") {
    return {
      ok: dropAuthority.canInsertBlockAt({
        blockName: source.data.blockName,
        // A missing outlet is never a valid insert target; the authority's
        // own falsy-guard rejects it, so an empty string maps to the same
        // result as the absent value.
        targetOutletName: outletName ?? "",
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
      ok: dropAuthority.canDropAt({ targetOutletName: outletName ?? "" }),
    };
  }
  return { ok: false };
}

interface ValidateInsideDropOptions {
  layoutQuery: WireframeLayoutQuery;
  dropAuthority: WireframeDropAuthority;
  source: DragSource;
  targetKey: string | null;
}

function validateInsideDrop({
  layoutQuery,
  dropAuthority,
  source,
  targetKey,
}: ValidateInsideDropOptions): ValidationResult {
  // Don't allow dropping a container inside itself.
  if (source.type === "wf-block" && source.data.blockKey === targetKey) {
    return { ok: false };
  }
  const outletName =
    targetKey == null
      ? undefined
      : layoutQuery.findEntryAndOutletSync(targetKey)?.outletName;
  return validateInsert({ dropAuthority, source, outletName });
}

/* Label builders — `i18n` keys with interpolations the descriptor
   carries pre-resolved (the overlay just renders the string). */

interface BoundaryLabelOptions {
  layoutQuery: WireframeLayoutQuery;
  source: DragSource;
  beforeKey: string | null;
  afterKey: string | null;
  childNoun?: string | null;
  childNounPlural?: string | null;
  beforeOrdinal?: number | null;
  afterOrdinal?: number | null;
}

function boundaryLabel({
  layoutQuery,
  source,
  beforeKey,
  afterKey,
  childNoun = null,
  childNounPlural = null,
  beforeOrdinal = null,
  afterOrdinal = null,
}: BoundaryLabelOptions): string {
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

interface InsideLabelOptions {
  layoutQuery: WireframeLayoutQuery;
  source: DragSource;
  blockName: string | null;
  targetKey: string | null;
  childNoun?: string | null;
  ordinal?: number | null;
}

function insideLabel({
  layoutQuery,
  source,
  blockName,
  targetKey,
  childNoun = null,
  ordinal = null,
}: InsideLabelOptions): string {
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

interface CellDropLabelOptions {
  layoutQuery: WireframeLayoutQuery;
  source: DragSource;
}

function cellDropLabel({ layoutQuery, source }: CellDropLabelOptions): string {
  const name = sourceDisplayName(layoutQuery, source);
  return source.type === "wf-palette-block"
    ? translate("wireframe.canvas.drop_preview.add_here", { name })
    : translate("wireframe.canvas.drop_preview.move_here", { name });
}

/* Dispatch payload builders — `wireframeDropDispatch.run` looks up
   `[action]` and calls it with `args` at drop time. */

interface InsertDispatchOptions {
  source: DragSource;
  targetKey: string | null;
  position: "before" | "after";
  containerKey: string | null;
  outletName: string;
}

function insertDispatch({
  source,
  targetKey,
  position,
  containerKey,
  outletName,
}: InsertDispatchOptions): DropDispatch {
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

interface SimpleDispatchOptions {
  source: DragSource;
  targetKey: string | null;
}

function insideDispatch({
  source,
  targetKey,
}: SimpleDispatchOptions): DropDispatch {
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

function cellDropDispatch({
  source,
  targetKey,
}: SimpleDispatchOptions): DropDispatch {
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

function sourceDisplayName(
  layoutQuery: WireframeLayoutQuery,
  source: DragSource
): string {
  if (source.type === "wf-palette-block") {
    return (
      layoutQuery.lookupBlockDisplayName?.(source.data.blockName) ||
      source.data.blockName ||
      "block"
    );
  }
  if (source.type === "wf-block") {
    const blockKey = source.data.blockKey;
    const located =
      blockKey == null ? null : layoutQuery.findEntryAndOutletSync(blockKey);
    if (located?.entry) {
      return decorateWithId(
        layoutQuery.lookupBlockDisplayName?.(located.entry.block) || "block",
        located.entry.id
      );
    }
  }
  return "block";
}

function targetDisplayName(
  layoutQuery: WireframeLayoutQuery,
  targetKey: string | null
): string | null {
  if (targetKey == null) {
    return null;
  }
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
function decorateWithId(name: string, id: string | undefined): string;
function decorateWithId(
  name: string | null,
  id: string | undefined
): string | null;
function decorateWithId(
  name: string | null,
  id: string | undefined
): string | null {
  if (!name) {
    return name;
  }
  if (!id) {
    return name;
  }
  return `${name} #${id}`;
}

function translate(key: string, vars?: object): string {
  return i18n(key, vars);
}
