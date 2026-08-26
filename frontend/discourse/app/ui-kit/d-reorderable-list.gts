import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import {
  associateDestroyableChild,
  isDestroying,
  registerDestructor,
} from "@ember/destroyable";
import { fn, hash } from "@ember/helper";
import { action, get } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import type Owner from "@ember/owner";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import type MenuService from "discourse/float-kit/services/menu";
import type A11yService from "discourse/services/a11y";
import { and, eq, not } from "discourse/truth-helpers";
import ItemScope from "discourse/ui-kit/-internals/cursor/item-scope";
import { step } from "discourse/ui-kit/-internals/cursor/navigation";
import {
  CHORD_TARGETS,
  MENU_CONTENT_SELECTOR,
} from "discourse/ui-kit/d-reorderable-list/-internals/constants";
import MoveMenuCoordinator from "discourse/ui-kit/d-reorderable-list/-internals/coordinators/move-menu-coordinator";
import ReorderAnnouncer from "discourse/ui-kit/d-reorderable-list/-internals/coordinators/reorder-announcer";
import MoveEngine from "discourse/ui-kit/d-reorderable-list/-internals/engine/move-engine";
import CreateRow from "discourse/ui-kit/d-reorderable-list/-internals/parts/create-row";
import HandlePart from "discourse/ui-kit/d-reorderable-list/-internals/parts/handle";
import RemovePart from "discourse/ui-kit/d-reorderable-list/-internals/parts/remove";
import type {
  DReorderableListSignature,
  MoveTarget,
  Row,
} from "discourse/ui-kit/d-reorderable-list/types";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dElement from "discourse/ui-kit/helpers/d-element";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget, {
  DropTargetEvent,
  registerDragAndDropTarget,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

export type {
  ReorderableGroupApi,
  ReorderableGroupMember,
  ReorderableMove,
  ReorderableRowApi,
} from "discourse/ui-kit/d-reorderable-list/types";

/**
 * A reorderable list: the standard shell for any surface where the user
 * changes the order of visible rows.
 *
 * The component owns the whole interaction — keyed iteration, the drag
 * handle, the move menu, the keyboard path, boundary state, drop
 * normalization, no-op suppression, focus restoration, and the screen-reader
 * announcement — so a consumer supplies only its row content and one
 * `@onMove` that projects the proposed visible order into its own store.
 * Every input method converges on a single commit: one callback and one
 * announcement per real move, and neither for a move that lands where it
 * started.
 *
 * The handle inside each row is the pointer affordance: the drag source and
 * the move menu's trigger at once. It is also an ordinary tab stop. The list
 * is not a composite widget, since its rows are content carrying their own
 * controls rather than alternatives to choose between, so nothing here manages
 * the tab sequence and every focusable thing in a row is reached in document
 * order.
 *
 * - **Pointer**: drag the handle, or click it and choose a destination. The
 *   menu is the single-pointer path WCAG 2.5.1 and 2.5.7 require, since a
 *   drag alone leaves anyone who cannot perform one with nothing.
 * - **Keyboard**: Tab reaches every handle and every control a row renders.
 *   Enter or Space on a handle opens its move menu through ordinary button
 *   activation, and Escape closes it. There is no mode to enter or leave.
 * - **Accelerators**: on a focused handle, a bare arrow moves focus to the
 *   neighbouring handle, stepping over the rows' own controls. Alt with an
 *   arrow moves the row one step, and Alt with Home/End sends it to an end.
 *   Every accelerator is refused anywhere but a handle, so a row's own field
 *   keeps its arrows and its chords, and none of them is ever the only path:
 *   assistive software that swallows one costs speed rather than access.
 *
 * A move at either end is refused, and the accelerator announces the refusal
 * rather than doing nothing: reaching an end is something the reader should be
 * told, and the silent boundary no-op is one of the failures this component
 * exists to stop surfaces from reinventing. The menu holds only the
 * destinations the row can reach, so the set it publishes to assistive
 * software is the set the cursor can land on. A row that can reach none of
 * them renders no handle rather than one that opens onto nothing.
 *
 * The list and row elements stay stylable and semantically flexible through
 * `@tag` / `@itemTag` / `@role` / `@itemRole`, which is what lets one
 * component serve plain lists and ARIA table shapes alike.
 *
 * @example
 * ```gjs
 * <DReorderableList
 *   @items={{this.sections}}
 *   @key="id"
 *   @label={{this.sectionLabel}}
 *   @onMove={{this.applyMove}}
 *   class="my-sections"
 * >
 *   <:row as |section|>
 *     <span>{{section.name}}</span>
 *   </:row>
 * </DReorderableList>
 * ```
 */
/**
 * What the arrow cursor may land on: one per row, its handle where it renders
 * one and the row itself where it does not. A frozen row still belongs to the
 * list the reader is walking, so leaving it out would make the cursor cover a
 * fraction of what is on screen.
 */
const CURSOR_TARGET = ".d-reorderable-list__handle, [data-reorderable-cursor]";

/**
 * Controls that demonstrably do nothing with Up and Down, so a press on one
 * can step the cursor from the row it sits in rather than dying there.
 *
 * An allow-list rather than a list of controls to avoid, so the failure
 * direction is safe: a caret, a radio in its group, a slider, a listbox, and
 * anything this does not recognise all keep their keys. A button that opens a
 * popup is excluded because the arrows may open it, which is also what keeps
 * the row's own handle out.
 */
const ARROW_INERT =
  '[role="switch"], [role="checkbox"], button:not([role]):not([aria-haspopup])';

export default class DReorderableList<T> extends Component<
  DReorderableListSignature<T>
> {
  @service declare a11y: A11yService;
  @service declare menu: MenuService;

  rowClassFor = (row: Row<T>): string | undefined => {
    const { rowClass } = this.args;
    if (typeof rowClass === "function") {
      return rowClass(row.item, { index: row.index, movable: row.movable });
    }
    return rowClass;
  };
  /**
   * Applied by the handle wherever it renders, so the component knows the row
   * kept its one control regardless of where a manual placement put it.
   */
  registerHandle = modifier((element: Element, [key]: [string]) => {
    this.#handles.set(key, element as HTMLElement);
    return () => {
      if (this.#handles.get(key) === element) {
        this.#handles.delete(key);
      }
    };
  });
  /**
   * Guards the manual-placement contract: a movable row under
   * `@controls="manual"` must place the yielded handle. It is the drag source,
   * the keyboard path and the single-pointer path at once, so a row that omits
   * it has no way to reorder at all. Checked once per row element, after its
   * first render — a consumer that conditionally removes its placed handle
   * later is beyond this guard's reach.
   */
  verifyKeyboardPath = modifier((element: Element) => {
    // The key is read from the element rather than taken as an argument: an
    // argument's tracking tag invalidates on every rows recompute, and a
    // function modifier that consumed it would tear down and re-run each
    // time. Reading only the element keeps this a strict once-per-element
    // lifecycle hook.
    if (!this.isManual) {
      return;
    }
    const key = element.getAttribute("data-reorderable-key") ?? "";
    schedule("afterRender", () => {
      if (isDestroying(this)) {
        return;
      }
      // A row with nowhere to go is yielded no handle to place, so it has
      // none to be missing.
      if (!this.rowFor(key)?.rendersHandle) {
        return;
      }
      assert(
        `d-reorderable-list: the manual row "${key}" renders no handle — place the yielded handle, which is its only drag, keyboard and single-pointer path`,
        this.#handles.has(key)
      );
    });
  });
  /**
   * Registers the list's root element as a drop target while the list is an
   * empty group member — the one state with no rows to land on. Applied
   * statically and registered imperatively: a conditionally curried modifier
   * breaks on the classic-component element wrapper the shell falls back to
   * for non-shortcut tags. Deliberately consumes `acceptsRootDrops`, so it
   * re-registers exactly when the items or group change — never mid-drag.
   */
  rootDropTarget = modifier((element: Element) => {
    if (!this.acceptsRootDrops) {
      return;
    }
    return registerDragAndDropTarget(element, () => ({
      accepts: this.dragType,
      position: "inside" as const,
      onDrop: this.onEmptyRootDrop,
    }));
  });

  /**
   * The keyboard accelerators, plus the focus bookkeeping the menu needs.
   *
   * Deliberately not `dRovingFocus`. That modifier implements the practice
   * page's composite pattern, where the group owns a single tab stop and the
   * arrows are the only way between items; its strategy stamps `tabindex="-1"`
   * on every item it manages. This list was built that way and it was reverted
   * after screen-reader testing: there is no ARIA role for one tab stop that
   * Tab descends into, so nothing told a reader that the arrows navigate or
   * that a row holds its own controls. A row is content carrying controls, not
   * one alternative among a set. So every handle stays an ordinary tab stop,
   * document order is the tab order, and the arrows are a redundant
   * accelerator over it — never the only path, so software that swallows one
   * costs speed rather than access.
   *
   * What is shared with that modifier is the part underneath the strategy:
   * `ItemScope` decides which candidates the cursor may land on and `step`
   * walks them. Only the tab-sequence ownership differs, and that is the whole
   * of the disagreement.
   *
   * Consumes nothing reactive: the row is resolved at event time.
   */
  moveKeys = modifier((element: Element) => {
    this.#listElement = element;

    const onKeydown = (event: Event) => {
      const { key, altKey, target } = event as KeyboardEvent;
      if (!(target instanceof HTMLElement)) {
        return;
      }
      const onCursorTarget = target.matches(CURSOR_TARGET);
      // A control the row renders answers for the arrows only when it has no
      // use for them itself. Everything else keeps its keys, so a caret is
      // safe by construction rather than by the list guessing at types.
      const onInertControl = !onCursorTarget && target.matches(ARROW_INERT);
      if (!onCursorTarget && !onInertControl) {
        return;
      }
      if (!altKey) {
        const delta = key === "ArrowDown" ? 1 : key === "ArrowUp" ? -1 : 0;
        if (!delta) {
          return;
        }
        const scope = new ItemScope(
          element as HTMLElement,
          CURSOR_TARGET,
          "skip"
        );
        const targets = scope.all();
        // Resolved through the owning row rather than by querying it for a
        // handle, so a manual placement nested anywhere in the row still
        // resolves, and a nested list's target can never be mistaken for this
        // row's.
        const row = target.closest("[data-reorderable-key]");
        const from = onCursorTarget
          ? targets.indexOf(target)
          : targets.findIndex(
              (candidate) => candidate.closest("[data-reorderable-key]") === row
            );
        const outcome = step(
          from,
          delta,
          targets,
          1,
          "vertical",
          false,
          (item) => scope.isNavigable(item)
        );
        if (outcome.kind === "move") {
          event.preventDefault();
          targets[outcome.index].focus();
        }
        return;
      }
      // The chord moves a row, so it belongs to the handle. A cursor row that
      // renders none has nothing to move.
      if (!target.matches(".d-reorderable-list__handle")) {
        return;
      }
      // An Alt chord pressed in a row's own control belongs to that control,
      // and Alt+Arrow is a live shortcut in a text field on several platforms.
      const destination = CHORD_TARGETS[key];
      if (!destination) {
        return;
      }
      const rowKey = target
        .closest("[data-reorderable-key]")
        ?.getAttribute("data-reorderable-key");
      if (!rowKey) {
        return;
      }
      event.preventDefault();
      event.stopPropagation();
      this.#engine.move(rowKey, destination, "keyboard");
    };

    const onFocusIn = (event: Event) => {
      if (!(event.target instanceof Element)) {
        return;
      }
      // The menu renders inside the list when it is not portaled, so its own
      // focus must not read as focus leaving the row it belongs to, which
      // would close the menu before a destination could be chosen.
      if (event.target.closest(MENU_CONTENT_SELECTOR)) {
        return;
      }
      // Any focus inside the row counts as being on the row, since its own
      // controls are part of it.
      const key = event.target
        .closest("[data-reorderable-key]")
        ?.getAttribute("data-reorderable-key");
      if (this.#focusedKey !== (key ?? null)) {
        this.#focusedKey = key ?? null;
        // The menu is anchored to one row, so focus that has moved on would
        // otherwise leave it floating over a row it no longer describes.
        if (
          this.menuCoordinator.openKey &&
          this.menuCoordinator.openKey !== this.#focusedKey
        ) {
          this.menuCoordinator.closeMenu(false);
        }
      }
    };

    const onFocusOut = () => {
      // Deferred past the render that may be moving the row: a move blurs its
      // handle until the after-render refocus lands, so only focus that has
      // settled outside the list clears the record.
      next(() => {
        if (
          isDestroying(this) ||
          this.#listElement?.contains(document.activeElement) ||
          document.activeElement?.closest(MENU_CONTENT_SELECTOR)
        ) {
          return;
        }
        this.#focusedKey = null;
      });
    };

    const onRowClick = (event: Event) => {
      if (!(event.target instanceof Element)) {
        return;
      }
      // Interactive content owns its clicks, and the handle is already the
      // menu trigger, so only the row's dead space reaches the focus below.
      if (
        event.target.closest(
          "button, a, input, select, textarea, [tabindex], [contenteditable='true']"
        )
      ) {
        return;
      }
      // A drag-select of row text is not a request to move focus.
      const selection = window.getSelection();
      if (selection && !selection.isCollapsed) {
        return;
      }
      const row = event.target.closest("[data-reorderable-key]");
      if (!row || !element.contains(row)) {
        return;
      }
      row.querySelector<HTMLElement>(".d-reorderable-list__handle")?.focus();
    };

    element.addEventListener("keydown", onKeydown, { capture: true });
    element.addEventListener("click", onRowClick);
    element.addEventListener("focusin", onFocusIn);
    element.addEventListener("focusout", onFocusOut);
    return () => {
      element.removeEventListener("keydown", onKeydown, { capture: true });
      element.removeEventListener("click", onRowClick);
      element.removeEventListener("focusin", onFocusIn);
      element.removeEventListener("focusout", onFocusOut);
      this.#listElement = null;
    };
  });

  /**
   * A row's handle element, for the row's drag registration to point at.
   *
   * Deliberately untracked: modifiers install children-first, so a row's own
   * handle is in the map before the row's drag registration reads it. Making
   * it reactive only reintroduced the write-after-read this ordering avoids.
   *
   * @param key - The row key.
   */
  handleFor = (key: string): HTMLElement | undefined => this.#handles.get(key);
  /** The list's one move menu. Public: the template reads its state. */
  menuCoordinator: MoveMenuCoordinator;
  /** The list's root element, held for post-move focus restoration. */
  #listElement: Element | null = null;
  /** The private drag discriminator used when the list stands alone. */
  #ownDragType = `d-reorderable-list:${guidFor(this)}`;

  /**
   * Each row's handle element, by key. Serves the manual-placement guard and
   * gives the shared menu something to anchor against when a row asks to open
   * it.
   */
  #handles = new Map<string, HTMLElement>();

  /**
   * The row focus is in, read only by the focus handler that decides whether
   * an open menu has been left behind.
   *
   * Deliberately untracked: the focus indicator is CSS on real DOM focus, so
   * nothing rendered consumes this. Tracking it means a `focusin` fired by the
   * after-render refocus writes a value the same computation has already read,
   * which is a backtracking-rerender assertion.
   */
  #focusedKey: string | null = null;

  /**
   * Everything this list says out loud. Holds the chord-run state, so it also
   * holds the timer that state needs, and cancels it from its own destructor.
   */
  #announcer: ReorderAnnouncer<T>;

  /** Every committed reorder, in-list and cross-list alike. */
  #engine: MoveEngine<T>;

  constructor(owner: Owner, args: DReorderableListSignature<T>["Args"]) {
    super(owner, args);

    this.#announcer = new ReorderAnnouncer<T>({
      a11y: this.a11y,
      getArgs: () => this.args,
      rows: () => this.rows,
    });
    // Without this the announcer is never destroyed, so its destructor never
    // runs and `isDestroying` inside it stays false for the process's life.
    associateDestroyableChild(this, this.#announcer);

    this.#engine = new MoveEngine<T>({
      args: () => this.args,
      rows: () => this.rows,
      listId: () => this.listIdOrDefault,
      announcer: this.#announcer,
      // Stays on the component: it resolves against the list element the
      // keyboard modifier installs on, which does not exist yet here.
      refocusIndex: (index: number) => this.#refocusIndex(index),
    });

    this.menuCoordinator = new MoveMenuCoordinator({
      menu: this.menu,
      args: () => this.args,
      listId: () => this.listIdOrDefault,
      handleFor: (key: string) => this.handleFor(key),
      rowFor: (key: string) => this.rowFor(key),
      siblings: () => this.siblings(),
      move: (key: string, target: MoveTarget) =>
        this.#engine.move(key, target, "menu"),
    });
    // Without this the coordinator is never destroyed, so a menu left open at
    // teardown stays registered with the service for the app's lifetime.
    associateDestroyableChild(this, this.menuCoordinator);

    const { group } = this.args;
    if (group && !this.args.listId) {
      // Reported after render rather than thrown here: an exception unwinding
      // a half-built render corrupts it. The list simply stays unregistered.
      schedule("afterRender", () => {
        if (isDestroying(this)) {
          return;
        }
        assert(
          "d-reorderable-list: @listId is required when the list joins a group",
          false
        );
      });
    } else if (group) {
      const unregister = group.registerMember({
        listId: this.args.listId!,
        listLabel: this.args.listLabel,
        getItems: () => this.args.items,
        acceptMove: (sourceListId: string, key: string, toIndex: number) => {
          this.#engine.commitCrossMove(sourceListId, key, toIndex, "menu");
          // Focus follows the item across: the row is destroyed in the source
          // list's iteration and rebuilt in this one, so only the destination
          // can put focus back on it. By landing slot, since the source's key
          // means nothing here on a list keyed by position.
          this.#refocusIndex(toIndex);
        },
        removalProjection: (key: string) => this.#engine.removalProjection(key),
      });
      registerDestructor(this, unregister);
    }
  }

  /**
   * The drag discriminator in force: the group's shared token when the list
   * is a member — which is what lets drags travel between members — and a
   * private per-instance one otherwise, so unrelated lists on one page can
   * never accept each other's drags.
   */
  get dragType(): string {
    return this.args.group?.token ?? this.#ownDragType;
  }

  get listTag(): string {
    return this.args.tag ?? "ul";
  }

  get itemTag(): string {
    return this.args.itemTag ?? "li";
  }

  /** The remove control's icon, defaulting to the list family's own. */
  get removeIcon(): string {
    return this.args.removeIcon ?? "xmark";
  }

  /** Whether the list places the remove control itself. */
  get rendersRemove(): boolean {
    return !!this.args.onRemove && !this.isManual;
  }

  /** Whether the remove control is the consumer's to place. */
  get rendersRemoveManually(): boolean {
    return !!this.args.onRemove && this.isManual;
  }

  get isManual(): boolean {
    return this.args.controls === "manual";
  }

  /**
   * The cross-list destinations this list's move menus offer: the group's
   * other named members. Empty for a standalone list, which is what makes the
   * menu collapse to its four in-list destinations without a conditional at
   * the call site.
   *
   * Handed to the handle as a function rather than an array, so the group is
   * consulted when a menu opens rather than while the row renders — members
   * are still registering at that point.
   */
  @action
  siblings(): { listId: string; listLabel: string }[] {
    return this.args.group?.siblings(this.listIdOrDefault) ?? [];
  }

  /** This list's move-payload identity: its group listId, or `"default"`. */
  get listIdOrDefault(): string {
    return this.args.listId ?? "default";
  }

  /**
   * Whether the list's root element accepts drops: only as an empty group
   * member, where there are no rows to land on. Reads `@items` directly
   * rather than `rows`, so the conditional target below re-curries only when
   * the items themselves change — never on drag-state churn.
   */
  get acceptsRootDrops(): boolean {
    return (
      !!this.args.group && this.args.items.length === 0 && !this.args.disabled
    );
  }

  /**
   * The per-row view models: identity, movability, boundary state, and the
   * translated control labels, computed in one pass so the template and the
   * event handlers read one consistent projection of `@items`.
   */
  get rows(): Row<T>[] {
    const { disabled, items, label, movable, removable } = this.args;
    const seen = new Set<string>();

    const rows = items.map((item, index) => {
      const key = this.#keyFor(item, index);
      assert(
        `d-reorderable-list: duplicate row key "${key}" — every item needs a unique key`,
        !seen.has(key)
      );
      seen.add(key);

      const itemLabel = label(item);
      const rowMovable = !disabled && (movable ? movable(item) : true);
      return {
        item,
        key,
        index,
        movable: rowMovable,
        isFirst: false,
        isLast: false,
        canMoveUp: false,
        canMoveDown: false,
        hasDestinations: false,
        rendersHandle: false,
        label: itemLabel,
        handleLabel: i18n("reorder.handle", { label: itemLabel }),
        // The description belongs to the row, but the element carrying the
        // text has to live inside the handle's button: a list element's
        // children are `li`, or the rows of whatever table shell a consumer
        // chose, and a bare `span` is legal in neither.
        descriptionId: `${guidFor(this)}-move-${index}`,
        removable: !disabled && (removable ? removable(item) : true),
        removeLabel: i18n("reorder.remove", { label: itemLabel }),
        yieldControls: rowMovable && this.isManual,
      };
    });

    const movableRows = rows.filter((row) => row.movable);
    // With a single movable item every direction is a no-op. A member list
    // still has its siblings to offer; a standalone one has nothing, and its
    // row drops the handle rather than opening onto an empty menu. Group
    // membership rather than the sibling count, because members are still
    // registering while the rows first project.
    const alone = movableRows.length < 2;
    const inGroup = !!this.args.group;
    for (const [seqIndex, row] of movableRows.entries()) {
      row.isFirst = seqIndex === 0;
      row.isLast = seqIndex === movableRows.length - 1;
      row.canMoveUp = !alone && !row.isFirst;
      row.canMoveDown = !alone && !row.isLast;
      row.hasDestinations = row.canMoveUp || row.canMoveDown || inGroup;
      row.rendersHandle = row.hasDestinations;
      row.yieldControls &&= row.rendersHandle;
    }

    return rows;
  }

  /**
   * Removes a row on the reader's behalf: hand the item to the consumer, say
   * so, and leave focus somewhere it can act again.
   *
   * Focus is the part a consumer cannot reasonably get right on its own. The
   * control that was just pressed is gone with its row, so focus would fall to
   * the document without help, and a reader clearing several entries would be
   * thrown to the top of the page after each one.
   *
   * @param key - The row to remove.
   */
  @action
  onRemove(key: string) {
    const row = this.rows.find((candidate) => candidate.key === key);
    if (!row?.removable) {
      return;
    }
    const index = row.index;
    this.args.onRemove?.(row.item, index);
    this.a11y.announce(i18n("reorder.removed", { label: row.label }));
    schedule("afterRender", () => {
      if (isDestroying(this)) {
        return;
      }
      const controls = Array.from(
        this.#listElement?.querySelectorAll<HTMLElement>(
          ".d-reorderable-list__remove"
        ) ?? []
      );
      // The slot the removed row occupied, which now holds the row that
      // followed it; at the end of the list, the one before it instead.
      const successor = controls[index] ?? controls.at(-1);
      successor?.focus();
    });
  }

  /**
   * The row a key names, for the menu to read boundary state from while open.
   *
   * @param key - The row key.
   */
  rowFor(key: string): Row<T> | undefined {
    return this.rows.find((row) => row.key === key);
  }

  /**
   * Refuses a row's own in-list drag as a drop candidate, which is what keeps
   * the drop indicator from offering a row a position relative to itself. A
   * same-valued key arriving from another group member is a different item
   * and stays droppable.
   *
   * @param rowKey - This row's key.
   * @param feedback - The target modifier's gate payload.
   */
  @action
  canDropOnRow(
    rowKey: string,
    { source }: { source: { data: Record<string, unknown> } }
  ) {
    return (
      source.data.key !== rowKey || source.data.listId !== this.listIdOrDefault
    );
  }

  /**
   * The drop path for one row target. The payload carries only the dragged
   * row's key; the item and both indices are resolved against the current
   * rows here, so a host that replaced its items mid-drag still lands the
   * drop on the right thing — or refuses it when the key is gone.
   *
   * @param targetKey - The key of the row the drop landed on.
   * @param event - The target modifier's drop payload.
   */
  @action
  onRowDrop(targetKey: string, { position, source }: DropTargetEvent) {
    const rows = this.rows;
    const targetRow = rows.find((candidate) => candidate.key === targetKey);
    if (!targetRow?.movable) {
      return;
    }

    const sourceListId = source.data.listId as string | undefined;
    if (this.args.group && sourceListId !== this.listIdOrDefault) {
      const toIndex = targetRow.index + (position === "after" ? 1 : 0);
      this.#engine.commitCrossMove(
        sourceListId,
        source.data.key as string,
        toIndex,
        "drag"
      );
      return;
    }

    const sourceRow = rows.find(
      (candidate) => candidate.key === source.data.key
    );
    if (!sourceRow?.movable) {
      return;
    }

    const seq = rows.filter((candidate) => candidate.movable);
    const from = seq.indexOf(sourceRow);
    let to = seq.indexOf(targetRow);
    if (position === "after") {
      to += 1;
    }
    if (from < to) {
      to -= 1;
    }

    this.#engine.commitSeqMove("drag", rows, seq, from, to);
  }

  /**
   * The drop path for the list's own root element, registered only while the
   * list is an empty group member — the one state with no rows to land on.
   *
   * @param event - The target modifier's drop payload.
   */
  @action
  onEmptyRootDrop({ source }: DropTargetEvent) {
    if (!this.acceptsRootDrops || this.rows.length > 0) {
      return;
    }
    this.#engine.commitCrossMove(
      source.data.listId as string | undefined,
      source.data.key as string,
      0,
      "drag"
    );
  }

  #keyFor(item: T, index: number): string {
    const { key } = this.args;
    if (key === "@index") {
      return String(index);
    }
    if (key) {
      return String(get(item as object, key));
    }
    return guidFor(item);
  }

  /**
   * Takes focus back onto a handle after its row moved in the DOM, which
   * blurs it. Without this a keyboard user lands on the body after one move
   * and cannot make a second.
   *
   * Addressed by visible index rather than by key, and resolved against the
   * projection as it stands after the render. A list keyed by position hands
   * the vacated key to whichever row filled the slot, so a key captured before
   * the move names the wrong row by the time this runs.
   *
   * @param index - The moved row's visible index after the move.
   */
  #refocusIndex(index: number) {
    schedule("afterRender", () => {
      if (isDestroying(this)) {
        return;
      }
      const row = this.rows[index];
      if (!row) {
        return;
      }
      const root = this.#listElement ?? document;
      root
        .querySelector<HTMLElement>(
          `[data-reorderable-key="${CSS.escape(row.key)}"] .d-reorderable-list__handle`
        )
        ?.focus();
    });
  }

  <template>
    {{#let (dElement this.listTag) as |List|}}
      <List
        class={{dConcatClass
          "d-reorderable-list"
          (if this.acceptsRootDrops "--empty-drop-target")
        }}
        role={{@role}}
        {{this.rootDropTarget}}
        {{this.moveKeys}}
        ...attributes
      >
        {{yield to="hint"}}
        {{yield to="header"}}
        {{#if this.rows.length}}
          {{#let (dElement this.itemTag) as |Item|}}
            {{#each this.rows key="key" as |row|}}
              {{! Two whole-row branches rather than one row with a conditional
                  modifier: a conditionally curried modifier is re-created every
                  time the rows recompute, and re-installing the drop target
                  mid-drag leaves the element with a dead registration. Applied
                  statically, the target registers once per row element. }}
              {{#if row.movable}}
                <Item
                  class={{dConcatClass
                    "d-reorderable-list__row"
                    (this.rowClassFor row)
                  }}
                  role={{@itemRole}}
                  data-reorderable-key={{row.key}}
                  data-reorderable-cursor={{unless row.rendersHandle "true"}}
                  tabindex={{unless row.rendersHandle "-1"}}
                  {{dDragAndDropSource
                    type=this.dragType
                    data=(hash key=row.key listId=this.listIdOrDefault)
                    dragHandle=(this.handleFor row.key)
                  }}
                  {{dDragAndDropTarget
                    accepts=this.dragType
                    canDrop=(fn this.canDropOnRow row.key)
                    onDrop=(fn this.onRowDrop row.key)
                  }}
                  {{this.verifyKeyboardPath}}
                >
                  {{#if (and (not this.isManual) row.rendersHandle)}}
                    <HandlePart
                      @row={{row}}
                      @onOpen={{this.menuCoordinator.openMenu}}
                      @isOpen={{eq this.menuCoordinator.openKey row.key}}
                      @register={{this.registerHandle}}
                    />
                  {{/if}}
                  {{yield
                    row.item
                    (hash
                      index=row.index
                      isFirst=row.isFirst
                      isLast=row.isLast
                      movable=row.movable
                      handle=(if
                        row.yieldControls
                        (component
                          HandlePart
                          row=row
                          onOpen=this.menuCoordinator.openMenu
                          isOpen=(eq this.menuCoordinator.openKey row.key)
                          register=this.registerHandle
                        )
                      )
                      remove=(if
                        (and this.rendersRemoveManually row.removable)
                        (component
                          RemovePart
                          row=row
                          icon=this.removeIcon
                          onRemove=this.onRemove
                        )
                      )
                    )
                    to="row"
                  }}
                  {{#if (and this.rendersRemove row.removable)}}
                    <RemovePart
                      @row={{row}}
                      @icon={{this.removeIcon}}
                      @onRemove={{this.onRemove}}
                    />
                  {{/if}}
                </Item>
              {{else}}
                {{! A frozen row renders no handle, so the row itself is what the
                    arrow cursor lands on. Out of the tab sequence: Tab reaches
                    the controls the row renders, not the row. }}
                <Item
                  class={{dConcatClass
                    "d-reorderable-list__row"
                    (this.rowClassFor row)
                  }}
                  role={{@itemRole}}
                  data-reorderable-key={{row.key}}
                  data-reorderable-cursor="true"
                  tabindex="-1"
                >
                  {{yield
                    row.item
                    (hash
                      index=row.index
                      isFirst=row.isFirst
                      isLast=row.isLast
                      movable=row.movable
                    )
                    to="row"
                  }}
                </Item>
              {{/if}}
            {{/each}}
          {{/let}}
        {{else}}
          {{yield to="empty"}}
        {{/if}}
        {{#if @allowCreate}}
          {{#if (has-block "create")}}
            {{yield to="create"}}
          {{else}}
            <CreateRow @itemTag={{this.itemTag}} @onCreate={{@onCreate}} />
          {{/if}}
        {{/if}}
      </List>
    {{/let}}
  </template>
}
