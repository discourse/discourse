import { tracked } from "@glimmer/tracking";
import { isDestroying } from "@ember/destroyable";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import Owner, { getOwner, setOwner } from "@ember/owner";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import {
  type FloatKitTrigger,
  MENU,
  type MenuOptions,
} from "discourse/float-kit/lib/constants";
import FloatKitInstance from "discourse/float-kit/lib/float-kit-instance";
import type MenuService from "discourse/float-kit/services/menu";
import { animateClosing } from "discourse/lib/animation-utils";
import type ModalService from "discourse/services/modal";

/**
 * The concrete float instance backing a menu. It holds the menu's options,
 * open/close state, and portal outlet, and implements the trigger and lifecycle
 * hooks that `FloatKitInstance` orchestrates. A menu refocuses its trigger when
 * it closes and, on mobile, closes through the modal service when it was shown
 * as a modal.
 */
export default class DMenuInstance extends FloatKitInstance {
  @service declare menu: MenuService;
  @service declare modal: ModalService;

  /** Whether the menu is currently open. */
  @tracked expanded = false;

  /**
   * Whether the trigger is disabled. While true, a trigger event (click/focus/hover/hold) does
   * not open the menu — the single reactive veto for every listener the base wires once at
   * registration. `<DMenu>` keeps this in sync with its `@disabled` argument; it does not touch
   * focusability or the trigger's own ARIA, which stay the caller's concern.
   */
  @tracked disabled = false;

  /**
   * Whether the menu's trigger is managed outside the `<DMenu />` component. It
   * is set when the menu is created through the `menu` service, where the
   * trigger and content live in separate parts of the DOM and are rendered by
   * `DHeadlessMenu` rather than by `DMenu`.
   */
  @tracked detachedTrigger = false;

  /**
   * The merged menu options: the defaults from `MENU.options` with the caller's
   * overrides applied in the constructor.
   */
  @tracked options: MenuOptions;
  @tracked portalOutletOverrideElement?: HTMLElement | null;

  @tracked _trigger: FloatKitTrigger;

  constructor(owner: Owner, options: Partial<MenuOptions> = {}) {
    super();

    setOwner(this, owner);
    this.options = { ...MENU.options, ...options };
    this.portalOutletOverrideElement = options.portalOutletElement;
  }

  get portalOutletElement() {
    return (
      this.portalOutletOverrideElement ||
      document.getElementById("d-menu-portals")
    );
  }

  get trigger() {
    return this._trigger;
  }

  set trigger(element: FloatKitTrigger) {
    this._trigger = element;
    this.id =
      (element instanceof HTMLElement && element.id) || guidFor(element);
    this.setupListeners();
  }

  get shouldTrapPointerDown() {
    return this.expanded;
  }

  @action
  async close(options = { focusTrigger: true }) {
    this.openedByDelayedHover = false;

    if (isDestroying(getOwner(this)!)) {
      return;
    }

    await animateClosing(this.content);

    if (this.renderInModal && this.expanded) {
      await this.modal.close();
    }

    await this.menu.close(this);

    if (options.focusTrigger) {
      this.triggerElement?.focus();
    }

    await super.close(options);
  }

  @action
  async show() {
    await super.show();
    await this.menu.show(this);
  }

  @action
  async onPointerMove(event: PointerEvent) {
    if (this.expanded && this.triggerElement?.contains(event.target as Node)) {
      return;
    }

    await this.onTrigger(event);
  }

  @action
  async onClick(event: MouseEvent) {
    cancel(this.delayedHoverTimeout);

    if (this.openedByDelayedHover) {
      this.openedByDelayedHover = false;
      return;
    }

    if (this.expanded && this.untriggers.includes("click")) {
      return await this.onUntrigger(event);
    }

    await this.onTrigger(event);
  }

  @action
  async onPointerLeave(event: PointerEvent) {
    if (this.untriggers.includes("hover")) {
      await this.onUntrigger(event);
    }
  }

  @action
  async onTrigger(event: Event) {
    // Consume the trigger event even when disabled, so a disabled trigger inside a clickable
    // ancestor doesn't fall through and activate it — an enabled trigger would have consumed it.
    event.stopPropagation();

    if (this.disabled) {
      this.openedByDelayedHover = false;
      return;
    }

    await this.options.beforeTrigger?.(this);

    if (this.disabled) {
      this.openedByDelayedHover = false;
      return;
    }

    await this.show();
  }

  @action
  async onUntrigger(event: Event) {
    event.stopPropagation();

    await this.close();
  }

  @action
  destroy() {
    this.close();
    this.tearDownListeners();
  }
}
