import { registerDestructor } from "@ember/destroyable";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import Modifier, { type ArgsFor } from "ember-modifier";
import { LAYOUT_MERGED_CELL_BLOCK } from "discourse/blocks";
import { registerDragAndDropAutoScroll } from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import {
  type DropTargetEvent,
  type DropTargetSource,
  registerDragAndDropTarget,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";
import type { DropDispatch } from "discourse/plugins/discourse-wireframe/discourse/lib/drop-dispatch";
import {
  flipPosition,
  isReversedFlexLayout,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/reversed-flex";
import { resolveLinearDrop } from "discourse/plugins/discourse-wireframe/discourse/lib/linear-drop";
import {
  type Indicator,
  resolveWrappingFlowDrop,
  type WrappingFlowDropResult,
} from "discourse/plugins/discourse-wireframe/discourse/lib/wrapping-flow-drop";
import type WireframeDragOverlayService from "../services/wireframe-drag-overlay";
import type WireframeDropAuthorityService from "../services/wireframe-drop-authority";
import type WireframeLayoutQueryService from "../services/wireframe-layout-query";

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
  /** Pointer x-coordinate in viewport pixels. */
  clientX: number;
  /** Pointer y-coordinate in viewport pixels. */
  clientY: number;
}

/**
 * The drag payloads this editor publishes, narrowed from the opaque record the
 * ui-kit drop target hands its callbacks: a moved block carries its own key, a
 * palette entry carries the block name / default args to insert.
 */
export type DragSource =
  | {
      /** Identifies an existing rendered block. */
      type: "wf-block";
      /** Existing block drag payload. */
      data: {
        /** Composite key of the dragged block. */
        blockKey: string | null;
      };
    }
  | {
      /** Identifies a new palette block. */
      type: "wf-palette-block";
      /** Palette block drag payload. */
      data: {
        /** Registered block name. */
        blockName: string;
        /** Default arguments for the new entry. */
        defaultArgs?: Record<string, unknown>;
      };
    };

/**
 * Reads a drop target's source as one of this editor's own drag kinds. The
 * ui-kit types `data` as an opaque record, since only the source that wrote it
 * knows its shape, so the narrowing has to happen at each consumer's boundary.
 */
export function asWireframeDragSource(source: DropTargetSource): DragSource {
  return source as unknown as DragSource;
}

/** Viewport-relative pixel rect for the slot-insert indicator. */
export interface DropGeometry {
  /** Top edge in viewport pixels. */
  top: number;
  /** Left edge in viewport pixels. */
  left: number;
  /** Indicator width in pixels. */
  width: number;
  /** Indicator height in pixels. */
  height: number;
}

/**
 * The raw descriptor the resolvers produce and hand to the drag-overlay
 * coordinator's `claimSlotInsert`. Structurally the coordinator's
 * `SlotDropDescriptor`.
 */
export interface DropDescriptor {
  /** Viewport geometry for the overlay. */
  geometry: DropGeometry;
  /** Semantic drop kind. */
  kind: string;
  /** Whether the authority service accepted the drop. */
  validity: "valid" | "invalid";
  /** Human-readable target label. */
  label: string;
  /** Deferred mutation payload for a valid drop. */
  dispatch: DropDispatch | null;
}

const ACCEPTED_KINDS = ["wf-block", "wf-palette-block"];

/** Outer-edge band (px) where drops fall through to the parent container. */
const EDGE_BAND = 12;

/** The PDND drop location the target callbacks receive. */
type DropLocation = {
  /** Current pointer snapshot. */
  current: {
    /** Pointer coordinates for the drag frame. */
    input: PointerInput;
  };
};

interface ContainerDropTargetSignature {
  /** Element registering the drop target. */
  Element: HTMLElement;
  /** Modifier arguments. */
  Args: {
    /** Named modifier arguments. */
    Named: {
      /** Composite key of the target container. */
      containerKey?: string | null;
      /** Outlet containing the target. */
      outletName: string;
      /** Layout mode controlling drop geometry. */
      mode: ContainerMode;
    };
    /** This modifier accepts no positional arguments. */
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
  /** Owns the single drop-preview overlay claim. */
  @service declare wireframeDragOverlay: WireframeDragOverlayService;
  /** Validates proposed insertions and moves. */
  @service declare wireframeDropAuthority: WireframeDropAuthorityService;
  /** Resolves layout entries and metadata for labels and geometry. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /** Cleanup for the active auto-scroll registration. */
  #autoScrollCleanup: (() => void) | null = null;
  /** Cleanup for the active drop-target registration. */
  #cleanup: (() => void) | null = null;
  /** Releases this modifier's current overlay claim. */
  #releaseDrop: (() => void) | null = null;

  /**
   * Creates the modifier and registers teardown.
   *
   * @param owner - Ember owner creating the modifier.
   * @param args - Initial modifier arguments.
   */
  constructor(owner: Owner, args: ArgsFor<ContainerDropTargetSignature>) {
    super(owner, args);
    registerDestructor(this, (instance) => instance.#detach());
  }

  /**
   * Registers drop handling for the current container mode.
   *
   * @param chromeElement - Chrome element carrying the modifier.
   * @param _positional - Unused positional arguments.
   * @param named - Target identity and layout mode.
   */
  modify(
    chromeElement: HTMLElement,
    _positional: [],
    {
      containerKey = null,
      outletName,
      mode,
    }: ContainerDropTargetSignature["Args"]["Named"]
  ): void {
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
      canDrop: ({
        input,
      }: {
        /** Current pointer coordinates. */
        input: PointerInput;
      }) => !shouldDeferToParent(input),
      onDragEnter: ({ source, location }: DropTargetEvent) => {
        // A container that declares a scroll axis (e.g. a horizontal slide
        // track) auto-scrolls when the cursor nears its edge, so a drag can
        // reach an off-screen child. Registered lazily on first entry — the
        // inner scroll element is resolved and present by drag time — and
        // cleared on detach.
        this.#enableAutoScroll(resolveContainer());
        claim(asWireframeDragSource(source), location.current.input);
      },
      onDrag: ({ source, location }: DropTargetEvent) =>
        claim(asWireframeDragSource(source), location.current.input),
      onDragLeave: () => this.#releaseDrop?.(),
      onDrop: ({
        location,
      }: {
        /** Final drag location. */
        location: DropLocation;
      }) => {
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
  #enableAutoScroll(container: HTMLElement | null): void {
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

  /** Clears drop-target, auto-scroll, and overlay registrations. */
  #detach(): void {
    this.#cleanup?.();
    this.#cleanup = null;
    this.#autoScrollCleanup?.();
    this.#autoScrollCleanup = null;
  }
}

/** Options accepted by {@link createContainerDropResolver}. */
export interface ContainerDropResolverOptions {
  /** Read-only layout service used to inspect target entries. */
  layoutQuery: WireframeLayoutQueryService;
  /** Authority service used to validate candidate drops. */
  dropAuthority: WireframeDropAuthorityService;
  /** Chrome element carrying the modifier. */
  chromeElement: HTMLElement;
  /** Composite key of the target container. */
  containerKey: string | null;
  /** Outlet containing the target container. */
  outletName: string;
  /** Layout mode controlling drop geometry. */
  mode: ContainerMode;
}

/** The geometry helpers a chrome's drop handling needs. */
export interface ContainerDropResolver {
  /** Resolves the inner element containing direct block children. */
  resolveContainer: () => HTMLElement;
  /** Checks whether an edge-band drop belongs to the parent target. */
  shouldDeferToParent: (input: PointerInput) => boolean;
  /** Resolves the preview and dispatch payload for a drag frame. */
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
 *
 * @param options - Services, target identity, element, and layout mode.
 * @returns Geometry helpers bound to the target chrome.
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
    const declaredAxis = container.dataset?.wfDropAxis;
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
      axis: declaredAxis === "x" || declaredAxis === "y" ? declaredAxis : axis,
      source,
    });
  };

  return { resolveContainer, shouldDeferToParent, descriptorFor };
}

// One candidate landing site inside a container: the layout-positioned wrapper
// element plus the block key and name of the child it stands for. `key` /
// `blockName` come off DOM attributes, so they may be absent.
type ChildCandidate = {
  /** Layout-positioned wrapper for the child. */
  wrapper: Element;
  /** Composite child key read from DOM metadata. */
  key: string | null;
  /** Registered child name read from DOM metadata. */
  blockName: string | null;
  /** Whether the child is a composite-part proxy. */
  isProxy: boolean;
};

/** Options accepted by {@link computeDescriptor}. */
export interface ComputeDescriptorOptions {
  /** Read-only layout service used to inspect target entries. */
  layoutQuery: WireframeLayoutQueryService;
  /** Authority service used to validate candidate drops. */
  dropAuthority: WireframeDropAuthorityService;
  /** Inner element containing direct block children. */
  container: HTMLElement;
  /** Chrome element carrying the modifier. */
  chromeElement?: HTMLElement | null;
  /** Current pointer coordinates. */
  input: PointerInput;
  /** Composite key of the target container. */
  containerKey: string | null;
  /** Outlet containing the target container. */
  outletName: string;
  /** Main axis used for flow geometry. */
  axis: "x" | "y";
  /** Block or palette item being dropped. */
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
 *
 * @param options - Services, target geometry, drag input, and source.
 * @returns The resolved drop descriptor, or `null` when no drop applies.
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
      outletName,
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
 * @param rect - Outer target bounds.
 * @param input - Current pointer coordinates.
 * @param band - Edge-band width in pixels.
 * @returns Whether the pointer lies in any outer edge band.
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
 *
 * @param chromeElement - Chrome whose owned exclusions should be checked.
 * @param input - Current pointer coordinates.
 * @returns Whether the pointer is over an owned excluded region.
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
 *
 * @param layoutQuery - Read-only layout service used to locate the entry.
 * @param key - Composite entry key to inspect.
 * @returns Whether the entry is a registered container.
 */
function childIsContainer(
  layoutQuery: WireframeLayoutQueryService,
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

type ValidationResult = {
  /** Whether the candidate drop is authorized. */
  ok: boolean;
};

type BoundaryDescriptorOptions = {
  /** Read-only layout service used to name target entries. */
  layoutQuery: WireframeLayoutQueryService;
  /** Authority service used to validate the insertion. */
  dropAuthority: WireframeDropAuthorityService;
  /** Inner element containing direct block children. */
  container: HTMLElement;
  /** Visible empty-state geometry for an empty container. */
  emptyRect?: DOMRect | null;
  /** Main axis used for boundary geometry. */
  axis: "x" | "y";
  /** Wrapped-band boundary geometry, when present. */
  indicator?: Indicator | null;
  /** Child immediately before the boundary. */
  before: ChildCandidate | null;
  /** Child immediately after the boundary. */
  after: ChildCandidate | null;
  /** Composite key of the target container. */
  containerKey: string | null;
  /** Outlet containing the target container. */
  outletName: string;
  /** Block or palette item being dropped. */
  source: DragSource;
  /** Singular noun used to describe a framed child. */
  childNoun?: string | null;
  /** Plural noun used to describe a framed child list. */
  childNounPlural?: string | null;
  /** One-based ordinal of the preceding child. */
  beforeOrdinal?: number | null;
  /** One-based ordinal of the following child. */
  afterOrdinal?: number | null;
};

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
 *
 * @param options - Boundary neighbours, geometry, source, and target context.
 * @returns The validated boundary descriptor, or `null` for a no-op drop.
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

type BoundaryGeometryOptions = {
  /** Main axis used for boundary geometry. */
  axis: "x" | "y";
  /** Viewport rectangle of the target container. */
  containerRect: DOMRect;
  /** Visible empty-state rectangle, when present. */
  emptyRect: DOMRect | null;
  /** Wrapped-band boundary geometry, when present. */
  indicator: Indicator | null;
  /** Child immediately before the boundary. */
  before: ChildCandidate | null;
  /** Child immediately after the boundary. */
  after: ChildCandidate | null;
};

/**
 * Pixel geometry for a boundary indicator. A real boundary is a 4px
 * line centred in the gap; an empty container paints its whole rect so
 * the (otherwise easy-to-miss) landing is unmistakable — over `emptyRect`
 * (the visible empty-state area) when one is supplied, else the container.
 *
 * @param options - Axis, container bounds, optional indicator, and neighbours.
 * @returns Pixel geometry for the drop preview.
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
 *
 * @param chromeElement - Chrome containing the visible empty state.
 * @returns The visible empty-state bounds, or `null` without a chrome.
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
 *
 * @param axis - Main axis used for the boundary.
 * @param before - Child immediately before the boundary.
 * @param after - Child immediately after the boundary.
 * @returns The viewport coordinate at the boundary center.
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
  if (after) {
    return nearOf(after);
  }
  // Reached only with exactly one neighbour (`boundaryGeometry` returns early
  // when both are absent), so this branch always has a `before`.
  return farOf(before!);
}

type InsideDescriptorOptions = {
  /** Read-only layout service used to describe the target. */
  layoutQuery: WireframeLayoutQueryService;
  /** Drop authorization service used to validate the target. */
  dropAuthority: WireframeDropAuthorityService;
  /** Viewport rectangle used for the drop preview. */
  rect: DOMRect;
  /** Composite key of the target container. */
  targetKey: string | null;
  /** Outlet containing the target container. */
  outletName: string;
  /** Registered name of the target container. */
  blockName: string | null;
  /** Block being dropped. */
  source: DragSource;
  /** Human-readable name for one child. */
  childNoun?: string | null;
  /** One-indexed child position used in the preview label. */
  ordinal?: number | null;
};

/**
 * Builds a descriptor for a drop inside a container child.
 *
 * @param options - Target geometry, identity, authorization, and source.
 * @returns The inside-drop descriptor.
 */
function buildInsideDescriptor({
  layoutQuery,
  dropAuthority,
  rect,
  targetKey,
  outletName,
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
    dispatch: validity.ok
      ? insideDispatch({ source, targetKey, outletName })
      : null,
  };
}

type CellChromeDescriptorOptions = {
  /** Read-only layout service used to name the source. */
  layoutQuery: WireframeLayoutQueryService;
  /** Chrome element representing the merged cell. */
  chromeElement: HTMLElement;
  /** Composite key of the merged-cell entry. */
  containerKey: string | null;
  /** Block or palette item being dropped. */
  source: DragSource;
};

/**
 * Builds the descriptor for a drop directly onto a merged-cell
 * chrome (the chrome IS the drop area; there's no inner
 * container to project onto). An empty cell is always a single
 * REPLACE landing, regardless of where the cursor sits within it.
 *
 * Mirrors `buildReplaceCellDescriptor` (used when a sibling
 * dragover hits a cell child) but reads geometry off the chrome
 * itself, since the modifier is attached to the cell's chrome.
 *
 * @param options - Cell chrome, stable key, source, and naming service.
 * @returns The replacement descriptor, or `null` for a self-drop.
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

type ReplaceCellDescriptorOptions = {
  /** Read-only layout service used to name the source. */
  layoutQuery: WireframeLayoutQueryService;
  /** Viewport rectangle of the merged cell. */
  rect: DOMRect;
  /** Composite key of the merged-cell entry. */
  targetKey: string | null;
  // Accepted for call-site symmetry with the INSIDE path; the cell replace
  // needs no block name.
  /** Registered target name, accepted for call-site symmetry. */
  blockName?: string | null;
  /** Block or palette item being dropped. */
  source: DragSource;
};

/**
 * Builds a descriptor for replacing a merged-cell child.
 *
 * @param options - Cell geometry, target identity, source, and naming service.
 * @returns The replacement descriptor, or `null` for a self-drop.
 */
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

type ValidateInsertOptions = {
  /** Authority service used to validate the insertion. */
  dropAuthority: WireframeDropAuthorityService;
  /** Block or palette item being dropped. */
  source: DragSource;
  /** Outlet receiving the insertion. */
  outletName?: string;
  // Accepted from the boundary call site for symmetry; not read here.
  /** Composite key of the surrounding container. */
  containerKey?: string | null;
  /** Composite key of the neighbouring target. */
  targetKey?: string | null;
};

/**
 * Checks whether a source can be inserted at a boundary.
 *
 * @param options - Authority, source, and destination context.
 * @returns The authorization result.
 */
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

type ValidateInsideDropOptions = {
  /** Read-only layout service used to locate the target outlet. */
  layoutQuery: WireframeLayoutQueryService;
  /** Authority service used to validate the insertion. */
  dropAuthority: WireframeDropAuthorityService;
  /** Block or palette item being dropped. */
  source: DragSource;
  /** Composite key of the destination container. */
  targetKey: string | null;
};

/**
 * Checks whether a source can be dropped inside a container.
 *
 * @param options - Layout, authority, source, and destination context.
 * @returns The authorization result.
 */
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

type BoundaryLabelOptions = {
  /** Read-only layout service used to resolve display names. */
  layoutQuery: WireframeLayoutQueryService;
  /** Block or palette item being dropped. */
  source: DragSource;
  /** Composite key of the preceding child. */
  beforeKey: string | null;
  /** Composite key of the following child. */
  afterKey: string | null;
  /** Singular noun used to describe a framed child. */
  childNoun?: string | null;
  /** Plural noun used to describe a framed child list. */
  childNounPlural?: string | null;
  /** One-based ordinal of the preceding child. */
  beforeOrdinal?: number | null;
  /** One-based ordinal of the following child. */
  afterOrdinal?: number | null;
};

/**
 * Builds localized copy for a boundary drop.
 *
 * @param options - Source, neighbours, and optional framed-child terminology.
 * @returns The localized drop-preview label.
 */
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

type InsideLabelOptions = {
  /** Read-only layout service used to resolve display names. */
  layoutQuery: WireframeLayoutQueryService;
  /** Block or palette item being dropped. */
  source: DragSource;
  /** Registered destination block name. */
  blockName: string | null;
  /** Composite key of the destination container. */
  targetKey: string | null;
  /** Singular noun used to describe a framed child. */
  childNoun?: string | null;
  /** One-based ordinal of the framed child. */
  ordinal?: number | null;
};

/**
 * Builds localized copy for an inside drop.
 *
 * @param options - Source and destination naming context.
 * @returns The localized drop-preview label.
 */
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

type CellDropLabelOptions = {
  /** Read-only layout service used to resolve the source name. */
  layoutQuery: WireframeLayoutQueryService;
  /** Block or palette item being dropped. */
  source: DragSource;
};

/**
 * Builds localized copy for filling a merged cell.
 *
 * @param options - Source and naming service.
 * @returns The localized drop-preview label.
 */
function cellDropLabel({ layoutQuery, source }: CellDropLabelOptions): string {
  const name = sourceDisplayName(layoutQuery, source);
  return source.type === "wf-palette-block"
    ? translate("wireframe.canvas.drop_preview.add_here", { name })
    : translate("wireframe.canvas.drop_preview.move_here", { name });
}

/* Dispatch payload builders — `wireframeDropDispatch.run` looks up
   `[action]` and calls it with `args` at drop time. */

type InsertDispatchOptions = {
  /** Block or palette item being dropped. */
  source: DragSource;
  /** Composite key of the neighbouring target. */
  targetKey: string | null;
  /** Position relative to the neighbouring target. */
  position: "before" | "after";
  /** Composite key of the surrounding container. */
  containerKey: string | null;
  /** Outlet receiving the insertion. */
  outletName: string;
};

/**
 * Builds the dispatch payload for a boundary insertion.
 *
 * @param options - Source and destination placement context.
 * @returns The mutation dispatch payload.
 */
function insertDispatch({
  source,
  targetKey,
  position,
  containerKey,
  outletName,
}: InsertDispatchOptions): DropDispatch | null {
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
  if (!source.data.blockKey) {
    return null;
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

type SimpleDispatchOptions = {
  /** Block or palette item being dropped. */
  source: DragSource;
  /** Composite key of the destination entry. */
  targetKey: string | null;
};

type InsideDispatchOptions = {
  /** Block being inserted or moved. */
  source: DragSource;
  /** Composite key of the destination container. */
  targetKey: string | null;
  /** Outlet containing the destination container. */
  outletName: string;
};

/**
 * Builds the dispatch payload for an inside insertion.
 *
 * @param options - Source and destination context.
 * @returns The mutation dispatch payload.
 */
function insideDispatch({
  source,
  targetKey,
  outletName,
}: InsideDispatchOptions): DropDispatch | null {
  if (source.type === "wf-palette-block") {
    return {
      action: "insertBlock",
      args: {
        blockName: source.data.blockName,
        defaultArgs: source.data.defaultArgs,
        targetKey,
        position: "inside",
        targetOutletName: outletName,
      },
    };
  }
  if (!source.data.blockKey) {
    return null;
  }
  return {
    action: "moveBlock",
    args: {
      sourceKey: source.data.blockKey,
      targetKey,
      position: "inside",
      targetOutletName: outletName,
    },
  };
}

/**
 * Builds the dispatch payload for filling a merged cell.
 *
 * @param options - Source and merged-cell target.
 * @returns The mutation dispatch payload.
 */
function cellDropDispatch({
  source,
  targetKey,
}: SimpleDispatchOptions): DropDispatch | null {
  if (!targetKey) {
    return null;
  }
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
  if (!source.data.blockKey) {
    return null;
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

/**
 * Resolves the display name of a dragged source.
 *
 * @param layoutQuery - Read-only layout service used for registered names.
 * @param source - Block or palette item being dropped.
 * @returns The human-readable source name.
 */
function sourceDisplayName(
  layoutQuery: WireframeLayoutQueryService,
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

/**
 * Resolves the display name of an existing target entry.
 *
 * @param layoutQuery - Read-only layout service used to locate the entry.
 * @param targetKey - Composite key of the target entry.
 * @returns The decorated target name, or `null` when unavailable.
 */
function targetDisplayName(
  layoutQuery: WireframeLayoutQueryService,
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
 *
 * @param name - Base display name.
 * @param id - Optional author-assigned identifier.
 * @returns The display name with its identifier when present.
 */
function decorateWithId(
  /** Base display name. */
  name: string,
  /** Optional author-assigned identifier. */
  id: string | undefined
): string;
function decorateWithId(
  /** Nullable base display name. */
  name: string | null,
  /** Optional author-assigned identifier. */
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

/**
 * Resolves localized drop-preview copy.
 *
 * @param key - Translation key.
 * @param vars - Optional interpolation values.
 * @returns The localized string.
 */
function translate(key: string, vars?: object): string {
  return i18n(key, vars);
}
