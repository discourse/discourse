import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { cancel, next as nextRunloop, schedule } from "@ember/runloop";
import type { DVirtualListApi } from "discourse/ui-kit/d-virtual-list";
import type { DRovingFocusApi } from "discourse/ui-kit/modifiers/d-roving-focus";
import LoadFeedbackTracker, {
  SkeletonRow,
} from "discourse/ui-kit/select/-internals/coordinators/load-feedback";
import SelectEngine, {
  SelectDescriptor,
  SelectItem as SelectItemModel,
} from "discourse/ui-kit/select/select-engine";

// A row's estimated height before measurement (~2.4em option). Windowing refines it from
// the real DOM; a reasonable estimate only reduces the initial scroll jump.
const ROW_HEIGHT_ESTIMATE = 38;

/** An engine descriptor with the DOM ids needed to render it. */
interface OptionRow extends SelectDescriptor {
  isSkeleton: false;
  // Ties an option to its group's header for `aria-describedby`: a header carries `headerId`,
  // each option in the group carries the same value as `groupHeaderId`, so a screen reader
  // announces the group name — membership a flat listbox can't convey by structure alone.
  headerId?: string;
  groupHeaderId?: string;
}

/** A rendered list row: a navigable engine descriptor or a frontier skeleton. */
type ListRow = OptionRow | SkeletonRow;

interface WindowedListCoordinatorOptions {
  engine: SelectEngine;
  feedback: LoadFeedbackTracker;
  getListboxId: () => string;
  isStaticModal: () => boolean;
}

export default class WindowedListCoordinator {
  /**
   * The `key` of the currently roving-highlighted option, tracked so the `--active` class is
   * rendered from state by each option (see {@link SelectItem}) instead of relying on the
   * modifier's imperative `classList` toggle — which the windowed list wipes when it
   * re-renders a row. The modifier still owns `aria-activedescendant` and navigation.
   */
  @tracked activeOptionKey: string | null = null;

  /**
   * The rows handed to the windowed list: the engine's descriptors, plus frontier skeleton
   * placeholders appended while a server source is fetching MORE rows at the tail (a reveal),
   * so the pending page reads as "more coming" in the list. Gated on `showRevealPlaceholder`,
   * which also carries the fast-source delay (no flash) and excludes a re-query (which
   * replaces the set rather than extending it). `buildItems` is recomputed per render on
   * purpose — its output reflects live selection/create/special state, not just `rawItems`.
   */
  buildListItems = (rawItems: SelectItemModel[]): readonly ListRow[] => {
    const listboxId = this.#getListboxId();
    const items: OptionRow[] = this.#engine
      .buildItems(rawItems)
      .map((descriptor) => {
        if (descriptor.flags.group) {
          return {
            ...descriptor,
            isSkeleton: false,
            headerId: `${listboxId}-group-${descriptor.groupOrdinal}`,
          };
        }
        return {
          ...descriptor,
          isSkeleton: false,
          groupHeaderId:
            descriptor.groupOrdinal == null
              ? undefined
              : `${listboxId}-group-${descriptor.groupOrdinal}`,
        };
      });
    if (this.#feedback.showRevealPlaceholder) {
      return [...items, ...this.#feedback.frontierSkeletons];
    }
    return items;
  };
  /** Estimated row height for the windowing engine before a row is measured. */
  estimateRowSize = (): number => ROW_HEIGHT_ESTIMATE;
  /**
   * The count of navigable options — structural headers/dividers, frontier skeletons, and
   * disabled options are excluded, so this equals the number of rows the roving modifier can
   * actually land on. Also records the option→raw index map: a logical jump target is translated
   * back to the row's raw array index for the virtualizer scroll.
   */
  navigableCount = (rows: readonly ListRow[]): number => {
    const optionRawIndices: number[] = [];
    rows.forEach((row, index) => {
      const option = this.optionRow(row);
      if (option?.logicalIndex != null) {
        optionRawIndices.push(index);
      }
    });
    this.#optionRawIndices = optionRawIndices;
    this.#logicalNavCount = optionRawIndices.length;
    return optionRawIndices.length;
  };
  optionRow = (row: ListRow): OptionRow | undefined =>
    row.isSkeleton === true ? undefined : row;
  /**
   * The raw row index the list should open on, so a windowed list reveals what is already
   * chosen instead of opening at row one. The roving cursor cannot do this alone: it seeds
   * from the mounted rows, and a selection below the fold is not among them.
   *
   * Deliberately a weaker condition than {@link shouldActivateSelected}, which governs where
   * Enter lands and so excludes `multiple`. Scrolling changes nothing about what Enter does,
   * and a multi-select's held rows are worth revealing too.
   */
  revealRowIndex = (rows: readonly ListRow[]): number | undefined => {
    if (!this.#engine.hasValue || this.#engine.filter !== "") {
      return undefined;
    }
    const index = rows.findIndex((row) => this.optionRow(row)?.flags.selected);
    return index === -1 ? undefined : index;
  };
  /**
   * Extends the virtualizer's window with the roving cursor's row once one exists (or the held
   * selection before that), plus the group header for every mounted option.
   *
   * The seed in `dRovingFocus` can only see MOUNTED rows, and the reveal scroll that brings an
   * off-window selection into view is deferred a runloop tick — so without this the seed of a
   * windowed list never sees the selection, activates row zero instead, and then *pins* row
   * zero. That pin is self-sustaining: the stale cursor stays mounted, so every later reconcile
   * finds it still present and keeps it. The user-visible result is not a misplaced highlight
   * but silent data loss — Enter activates row zero and replaces the held value with the first
   * item, only ever past the fold.
   *
   * `??`, never `||`: index 0 is a legitimate pin.
   */
  windowPins = (rows: readonly ListRow[]) => {
    const pin = this._activePinnedIndex ?? this.revealRowIndex(rows);
    const headerIndices = this.#headerIndices(rows);

    return (indices: readonly number[]) => {
      const extras: Array<number | undefined> = pin == null ? [] : [pin];
      const collectHeader = (index: number) => {
        const row = rows[index];
        const option = row && this.optionRow(row);
        if (!option || option.groupOrdinal == null) {
          return;
        }
        extras.push(headerIndices.get(option.groupOrdinal));
      };

      indices.forEach(collectHeader);
      if (pin != null) {
        collectHeader(pin);
      }
      return extras.filter((index): index is number => index != null);
    };
  };

  #engine: SelectEngine;
  #feedback: LoadFeedbackTracker;
  #getListboxId: () => string;
  #isStaticModal: () => boolean;
  #listboxApi: DVirtualListApi | null = null;
  #listboxRoving: DRovingFocusApi | null = null;
  #jumpTimer?: ReturnType<typeof nextRunloop>;
  #lastRows?: readonly ListRow[];
  #lastHeaderIndices = new Map<number, number>();

  // Maps a logical option ordinal to its raw index in the rendered row array, so a jump target
  // (logical) can be scrolled through the virtualizer (which addresses rows by raw index).
  #optionRawIndices: number[] = [];

  // The navigable option count, written by `navigableCount` as the list renders and read by
  // the jump handler to clamp a target. Kept off the template so a jump never clamps against a
  // stale window.
  #logicalNavCount = 0;

  // The active row's RAW array index (its virtualizer `data-index`), fed to the window extension
  // alongside the headers for mounted groups. Not a logical option ordinal: with group headers
  // the two diverge, and the roving modifier addresses options by `data-logical-index` instead
  // (see #optionRawIndices).
  @tracked _activePinnedIndex: number | undefined = undefined;

  constructor({
    engine,
    feedback,
    getListboxId,
    isStaticModal,
  }: WindowedListCoordinatorOptions) {
    this.#engine = engine;
    this.#feedback = feedback;
    this.#getListboxId = getListboxId;
    this.#isStaticModal = isStaticModal;
    registerDestructor(this, () => cancel(this.#jumpTimer));
  }

  /**
   * `dRovingFocus` hands `onActivate` the active option element; clicking it runs the
   * same handler as a pointer click, so keyboard and pointer share one selection path.
   */
  @action
  activateElement(element: HTMLElement): void {
    element.click();
  }

  /**
   * Static in the mobile modal: on open, move DOM focus onto the first (or the roving-`0`)
   * option, since the list lives in an `aria-modal` dialog the out-of-modal trigger can't
   * control. A no-op for every other variant/surface, which keep focus on their controller.
   */
  @action
  focusListboxIfSimple(element: HTMLElement): void {
    if (!this.#isStaticModal()) {
      return;
    }
    schedule("afterRender", () => {
      // Resolve the target inside the flush: `dRovingFocus` stamps `tabindex="0"` on the
      // selected (or first) option during this same afterRender, so reading it earlier could
      // capture the fallback first option before roving has chosen the real tab stop.
      const target =
        element.querySelector<HTMLElement>('[role="option"][tabindex="0"]') ??
        element.querySelector<HTMLElement>('[role="option"]');
      if (target?.isConnected) {
        target.focus({ preventScroll: true });
        // Focus is placed directly here, not through the roving modifier's `#setActive`, so
        // `onActiveChange` never fires to seed the pin. Seed it now: a Home/End/Page jump
        // before the first arrow keypress would otherwise scroll with nothing pinned, unmount
        // the focused row, and drop focus to `<body>`.
        this.activeOptionKey = target.dataset.optionKey ?? null;
        this._activePinnedIndex =
          target.dataset.index == null
            ? undefined
            : Number(target.dataset.index);
      }
    });
  }

  @action
  handleJump(target: number, direction: "forward" | "backward"): void {
    cancel(this.#jumpTimer);
    if (this.#logicalNavCount === 0) {
      return;
    }

    target = this.#clampJumpTarget(target);
    this.#scrollToJumpTarget(target, direction);
    this.#jumpTimer = nextRunloop(() =>
      this.#reconcileJump(target, direction, 0)
    );
  }

  @action
  registerListboxApi(api: DVirtualListApi): void {
    this.#listboxApi = api;
  }

  /**
   * Re-measures the list against the overlay's applied size.
   *
   * The engine measures its scroll element as it mounts, which happens while the overlay is
   * still unpositioned and therefore has no height — so the first window computes empty. The
   * correcting measurement would otherwise arrive only when a resize is observed, on the
   * browser's schedule, leaving the list blank until then.
   */
  @action
  remeasureListbox(): void {
    this.#listboxApi?.remeasureViewport();
  }

  @action
  registerListboxRoving(api: DRovingFocusApi | null): void {
    this.#listboxRoving = api;
  }

  reannounceActive(): boolean {
    return this.#listboxRoving?.reannounceActive() ?? false;
  }

  /**
   * Drops the roving highlight key when the list unmounts, so a reopened list does not render a
   * stale `--active`. The list also unmounts mid-session when a slow re-query swaps in the
   * skeleton, which is exactly when the old highlight must not survive.
   */
  @action
  releaseListbox(): void {
    cancel(this.#jumpTimer);
    // Drop the roving highlight key on close so a reopened list does not render a stale
    // `--active` (the modifier reports the active option only while it moves the cursor, so
    // it never reports the clearing on teardown).
    this.activeOptionKey = null;
    this._activePinnedIndex = undefined;
    this.#listboxApi = null;
    this.#listboxRoving = null;
    this.#jumpTimer = undefined;
  }

  @action
  resetListScroll(): void {
    cancel(this.#jumpTimer);
    this.#listboxApi?.scrollToIndex(0, {
      align: "start",
      behavior: "auto",
    });
  }

  /**
   * `dRovingFocus` reports the highlighted option element on every cursor move (and the
   * initial auto-seed), or `null` when the highlight is cleared — e.g. the active row was
   * disabled by the cap. We record its `key` so each option renders its own `--active` from
   * state; a `null` clears it, so no disabled row keeps the highlight. The element carries the
   * key via `data-option-key` (stamped in the template).
   */
  @action
  trackActiveOption(
    element: HTMLElement | null,
    meta?: { pointer: boolean }
  ): void {
    // A pointer press moves the cursor but does not SHOW it, the same distinction `:focus-visible`
    // draws: someone working with the mouse is looking at what they clicked, and a highlight
    // appearing on that row reads as a second kind of selection. The cursor still moves, so the
    // first arrow key continues from the row they acted on rather than jumping back to the top.
    this.activeOptionKey = meta?.pointer
      ? null
      : (element?.dataset.optionKey ?? null);
    this._activePinnedIndex =
      element?.dataset.index == null
        ? undefined
        : Number(element.dataset.index);
  }

  #clampJumpTarget(target: number): number {
    return Math.max(0, Math.min(target, this.#logicalNavCount - 1));
  }

  #reconcileJump(
    target: number,
    direction: "forward" | "backward",
    attempt: number
  ): void {
    if (this.#listboxRoving?.focusLogicalIndex(target)) {
      this.#jumpTimer = undefined;
      return;
    }

    if (attempt < 1 && this.#logicalNavCount > 0) {
      target = this.#clampJumpTarget(target);
      this.#scrollToJumpTarget(target, direction);
      this.#jumpTimer = nextRunloop(() =>
        this.#reconcileJump(target, direction, attempt + 1)
      );
      return;
    }

    this.#jumpTimer = undefined;
    if (direction === "forward") {
      this.#listboxRoving?.focusLast();
    } else {
      this.#listboxRoving?.focusFirst();
    }
  }

  #scrollToJumpTarget(target: number, direction: "forward" | "backward"): void {
    // `target` is a logical option ordinal; the virtualizer scrolls by raw row index, which
    // diverges once headers/dividers are interleaved. Translate before scrolling.
    const rawIndex = this.#optionRawIndices[target] ?? target;
    this.#listboxApi?.scrollToIndex(rawIndex, {
      align: direction === "forward" ? "end" : "start",
      behavior: "auto",
    });
  }

  #headerIndices(rows: readonly ListRow[]): Map<number, number> {
    if (rows !== this.#lastRows) {
      const headerIndices = new Map<number, number>();
      rows.forEach((row, index) => {
        const option = this.optionRow(row);
        if (option?.flags.group) {
          headerIndices.set(option.groupOrdinal!, index);
        }
      });
      this.#lastRows = rows;
      this.#lastHeaderIndices = headerIndices;
    }
    return this.#lastHeaderIndices;
  }
}
