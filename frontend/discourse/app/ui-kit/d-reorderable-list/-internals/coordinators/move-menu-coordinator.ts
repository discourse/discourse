import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import {
  MENU_CONTENT_SELECTOR,
  MENU_IDENTIFIER,
} from "discourse/ui-kit/d-reorderable-list/-internals/constants";
import MoveMenu from "discourse/ui-kit/d-reorderable-list/-internals/parts/move-menu";
import type {
  MoveTarget,
  ReorderableGroupApi,
  Row,
} from "discourse/ui-kit/d-reorderable-list/types";

/** The arguments the menu reads, resolved per call rather than captured. */
interface MoveMenuArgs {
  group?: ReorderableGroupApi;
}

interface MoveMenuCoordinatorOptions {
  owner: Owner;

  /** The list's current arguments; never a snapshot. */
  args: () => MoveMenuArgs;

  /** The list's group id, or its standalone default. */
  listId: () => string;

  /** The handle element a row's menu anchors to. */
  handleFor: (key: string) => HTMLElement | undefined;

  /**
   * The row a menu item acts on, called while the menu renders rather than
   * when it opens, so boundary marks reflect the list as it currently stands.
   */
  rowFor: (key: string) => Row<unknown> | undefined;

  /** The other group members this list can send a row to. */
  siblings: () => { listId: string; listLabel: string }[];

  /** Commits an in-list move chosen from the menu. */
  move: (key: string, target: MoveTarget) => void;
}

/**
 * The list's one move menu, re-anchored per row rather than built per row.
 *
 * A list is arbitrarily long, so one instance and one set of listeners is a
 * cost that scales with the wrong thing. The menu therefore belongs here and
 * not to the handle, and the handle carries only the ARIA that says which row
 * is open.
 */
export default class MoveMenuCoordinator {
  /**
   * The list's one menu, created on first use and re-anchored per row. Tracked
   * because the template renders it, and it does not exist until a row asks.
   */
  @tracked menu: DMenuInstance | null = null;

  /**
   * The row whose menu is open, and the list's only record of it. One menu
   * means one answer: with an instance per row there were as many claims about
   * what was open as there were rows, and keeping them agreeing was work the
   * design should not have needed.
   */
  @tracked openKey: string | null = null;

  #owner: Owner;
  #args: () => MoveMenuArgs;
  #listId: () => string;
  #handleFor: (key: string) => HTMLElement | undefined;
  #rowFor: (key: string) => Row<unknown> | undefined;
  #siblings: () => { listId: string; listLabel: string }[];
  #move: (key: string, target: MoveTarget) => void;

  constructor({
    owner,
    args,
    listId,
    handleFor,
    rowFor,
    siblings,
    move,
  }: MoveMenuCoordinatorOptions) {
    this.#owner = owner;
    this.#args = args;
    this.#listId = listId;
    this.#handleFor = handleFor;
    this.#rowFor = rowFor;
    this.#siblings = siblings;
    this.#move = move;
  }

  /**
   * Opens the list's one menu against a row's handle, creating it on first use.
   *
   * The instance is re-anchored rather than replaced, so a long list costs one
   * menu and one set of listeners no matter how many rows it has.
   *
   * @param key - The row whose handle was activated.
   */
  @action
  async openMenu(key: string) {
    const trigger = this.#handleFor(key);
    if (!trigger) {
      return;
    }

    if (this.openKey === key) {
      await this.closeMenu();
      return;
    }

    const instance = this.#menuInstance();
    // Listeners are off, so the trigger is only an anchor and reassigning it
    // is how one menu serves every row. The teardown is still required: the
    // base binds a pointer guard to whatever trigger it is given.
    instance.tearDownListeners();
    instance.trigger = trigger;
    instance.options = {
      ...instance.options,
      data: { list: this.#menuData(), key },
    };

    this.openKey = key;
    await instance.show();
    this.#focusFirstDestination();
  }

  /**
   * Puts focus on the first destination the reader can actually choose, or on
   * the first one of any kind when every destination is refused, so the menu
   * never opens with focus nowhere.
   */
  #focusFirstDestination() {
    const content = document.querySelector(MENU_CONTENT_SELECTOR);
    if (!content) {
      return;
    }
    const items = Array.from(
      content.querySelectorAll<HTMLElement>(".d-reorderable-list__move-item")
    );
    const target =
      items.find((item) => item.getAttribute("aria-disabled") !== "true") ??
      items[0];
    target?.focus();
  }

  /**
   * Closes the list's menu, if it is open.
   *
   * @param focusTrigger - Whether to hand focus back to the handle the menu
   *   was opened from. False when focus has already moved elsewhere: the
   *   menu's own habit of refocusing its trigger would otherwise drag focus
   *   back to the row the reader just left.
   */
  @action
  async closeMenu(focusTrigger = true) {
    this.openKey = null;
    if (this.menu?.expanded) {
      await this.menu.close({ focusTrigger });
    }
  }

  /**
   * The list's one menu, built on first open.
   *
   * Built rather than obtained from the `menu` service so that it keeps an
   * attached trigger: a service-created menu is rendered by the app-root
   * `DMenus`, which a component rendering in isolation has no access to. This
   * list renders its own, and `DFloatPortal` still teleports the content out
   * of the row's stacking context.
   */
  #menuInstance(): DMenuInstance {
    this.menu ??= new DMenuInstance(this.#owner, {
      identifier: MENU_IDENTIFIER,
      placement: "bottom-start",
      component: MoveMenu,
      listeners: false,
      autoUpdate: true,
      // The panel holds a list of buttons and nothing else — no filter, no
      // controller of its own — so the float element steps out of the way
      // rather than announcing itself as a dialog wrapped around them.
      contentRole: "none",
      // Focus is placed by hand after opening, not by the tab trap: the trap
      // takes the first focusable, and a destination marked unavailable is
      // still focusable. A row at either boundary would open on a dead item,
      // and a list with one row has nothing but dead items above the
      // cross-list entries.
      autofocus: false,
      onClose: () => (this.openKey = null),
    });
    return this.menu;
  }

  /**
   * A move chosen from the menu: commit, then close and hand focus back to the
   * handle, which the closing float would otherwise return to its pre-open
   * position.
   *
   * @param key - The row to move.
   * @param target - Where to move it.
   * @param close - Closes the menu the item was chosen from.
   */
  @action
  onMenuMove(key: string, target: MoveTarget) {
    // Closed without returning focus to the trigger: the move's own refocus
    // is what puts focus back, on the row that actually moved.
    this.closeMenu(false);
    this.#move(key, target);
  }

  /**
   * A cross-list move chosen from the menu, which is the only way to reach
   * another member without a pointer.
   *
   * @param key - The row to move.
   * @param listId - The destination member.
   * @param close - Closes the menu the item was chosen from.
   */
  @action
  onMenuMoveToList(key: string, listId: string, close: () => void) {
    close();
    const member = this.#args().group?.lookupMember(listId);
    if (!member) {
      return;
    }
    // The destination lands the item, exactly as it does for a drop, because
    // the projections it needs are its own. This list only supplies the key.
    member.acceptMove(this.#listId(), key, member.getItems().length);
  }

  /**
   * What the menu part is handed as its list.
   *
   * Assembled in one place because the four members no longer share an owner:
   * the row lookups belong to the component, the move handlers to this
   * coordinator. Every one stays a live call, since the part reads them while
   * it renders.
   */
  #menuData() {
    return {
      rowFor: (key: string) => this.#rowFor(key),
      siblings: () => this.#siblings(),
      onMenuMove: (key: string, target: MoveTarget) =>
        this.onMenuMove(key, target),
      onMenuMoveToList: (key: string, listId: string, close: () => void) =>
        this.onMenuMoveToList(key, listId, close),
    };
  }
}
