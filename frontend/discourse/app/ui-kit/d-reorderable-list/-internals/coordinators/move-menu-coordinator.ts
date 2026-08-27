import { tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import type MenuService from "discourse/float-kit/services/menu";
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
  /** The service that owns every menu's lifecycle and renders its content. */
  menu: MenuService;

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

  /**
   * Whether a step in this direction, refused at the list's own end, would
   * carry the row into the adjacent group member instead. The menu offers the
   * direction when it would, so what it shows and what the accelerator does
   * stay the same answer.
   */
  canSpill: (target: MoveTarget) => boolean;
}

/**
 * The list's move menu, shown through the `menu` service against whichever
 * row's handle was activated.
 *
 * The menu belongs here rather than to the handle: a list is arbitrarily long,
 * and a menu per row is a cost that scales with the wrong thing. The handle
 * carries only the ARIA saying which row is open. The service owns the
 * instance's lifecycle and renders its content at the app root, so this holds
 * no instance of its own beyond the one needed to close on its own terms.
 */
export default class MoveMenuCoordinator {
  /**
   * The row whose menu is open, and the list's only record of it. One menu
   * means one answer: with an instance per row there were as many claims about
   * what was open as there were rows, and keeping them agreeing was work the
   * design should not have needed.
   */
  @tracked openKey: string | null = null;

  #menuService: MenuService;
  #args: () => MoveMenuArgs;
  #listId: () => string;
  #handleFor: (key: string) => HTMLElement | undefined;
  #rowFor: (key: string) => Row<unknown> | undefined;
  #siblings: () => { listId: string; listLabel: string }[];
  #move: (key: string, target: MoveTarget) => void;
  #canSpill: (target: MoveTarget) => boolean;

  /**
   * The menu the service last opened for this list, held only so a close can
   * ask for the trigger not to be refocused. The service's own `close` takes
   * no such option.
   */
  #instance: DMenuInstance | null = null;

  constructor({
    menu,
    args,
    listId,
    handleFor,
    rowFor,
    siblings,
    move,
    canSpill,
  }: MoveMenuCoordinatorOptions) {
    this.#menuService = menu;
    this.#args = args;
    this.#listId = listId;
    this.#handleFor = handleFor;
    this.#rowFor = rowFor;
    this.#siblings = siblings;
    this.#move = move;
    this.#canSpill = canSpill;

    // The content is rendered by the app-root host, not by this list, so a
    // list torn down while open would otherwise leave a menu anchored to a
    // removed trigger and registered with the service for the app's lifetime.
    registerDestructor(this, () => this.#instance?.destroy());
  }

  /**
   * Opens the move menu against a row's handle.
   *
   * Every row shares one identifier, which is what makes opening a second row's
   * menu close the first: the service enforces one open menu per identifier,
   * across sibling lists as well as within one.
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

    this.openKey = key;
    this.#instance =
      (await this.#menuService.show(trigger, {
        identifier: MENU_IDENTIFIER,
        placement: "bottom-start",
        component: MoveMenu,
        autoUpdate: true,
        // The panel holds a list of buttons and nothing else — no filter, no
        // controller of its own — so the float element steps out of the way
        // rather than announcing itself as a dialog wrapped around them.
        contentRole: "none",
        // Not the tab trap: containment belongs to a surface that owns the
        // screen until dismissed, and this one shows nothing to say that Tab
        // has stopped meaning "move on". Tab instead dismisses the menu and
        // resumes the page's sequence from the handle it was opened at.
        inlineTabOrder: true,
        data: { list: this.#menuData(), key },
        onClose: () => (this.openKey = null),
      })) ?? null;

    this.#focusFirstDestination();
  }

  /**
   * Puts focus on the first destination.
   *
   * Every destination the menu renders is one the row can take, so the first
   * of them is always a legitimate landing spot. A row left with only
   * cross-list entries opens on the first of those, and one with nothing at
   * all leaves focus on the handle rather than stranding it on the document.
   *
   * Focused without scrolling: the float is placed asynchronously, so at this
   * point it can still be sitting at the document origin, and asking the
   * browser to reveal it throws the reader to the top of the page they were
   * working in. The menu is opened from a handle that is on screen already, so
   * there is nothing to reveal.
   */
  #focusFirstDestination() {
    const content = document.querySelector(MENU_CONTENT_SELECTOR);
    if (!content) {
      return;
    }
    content
      .querySelector<HTMLElement>(".d-reorderable-list__move-item")
      ?.focus({ preventScroll: true });
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
    if (this.#instance?.expanded) {
      // Closed through the instance rather than the service, which offers no
      // say over the trigger refocus.
      await this.#instance.close({ focusTrigger });
    }
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
    member.acceptMove(this.#listId(), key, member.getItems().length, "menu");
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
      canSpill: (target: MoveTarget) => this.#canSpill(target),
      onMenuMove: (key: string, target: MoveTarget) =>
        this.onMenuMove(key, target),
      onMenuMoveToList: (key: string, listId: string, close: () => void) =>
        this.onMenuMoveToList(key, listId, close),
    };
  }
}
