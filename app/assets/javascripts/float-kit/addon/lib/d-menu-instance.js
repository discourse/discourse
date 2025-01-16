import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { MENU } from "float-kit/lib/constants";
import FloatKitInstance from "float-kit/lib/float-kit-instance";

export default class DMenuInstance extends FloatKitInstance {
  @service menu;
  @service site;
  @service modal;

  /**
   * Indicates whether the menu is expanded or not.
   * @property {boolean} expanded - Tracks the state of menu expansion, initially set to false.
   */
  @tracked expanded = false;

  /**
   * Specifies whether the trigger for opening/closing the menu is detached from the menu itself.
   * This is the case when a menu is trigger programmatically instead of through the <DMenu /> component.
   * @property {boolean} detachedTrigger - Tracks whether the trigger is detached, initially set to false.
   */
  @tracked detachedTrigger = false;

  /**
   * Configuration options for the DMenuInstance.
   * @property {Object} options - Options object that configures the menu behavior and display.
   */
  @tracked options;

  @tracked _trigger;

  constructor(owner, options = {}) {
    super(...arguments);

    setOwner(this, owner);
    this.options = { ...MENU.options, ...options };
  }

  get portalOutletElement() {
    return document.getElementById("d-menu-portals");
  }

  get trigger() {
    return this._trigger;
  }

  set trigger(element) {
    this._trigger = element;
    this.id = element.id || guidFor(element);
    this.setupListeners();
  }

  @action
  async close(options = { focusTrigger: true }) {
    if (getOwner(this).isDestroying) {
      return;
    }

    await super.close(...arguments);

    if (this.site.mobileView && this.options.modalForMobile) {
      await this.modal.close();
    }

    await this.menu.close(this);

    if (options.focusTrigger) {
      this.trigger?.focus?.();
    }

    await this.options.onClose?.(this);
  }

  @action
  async show() {
    await super.show(...arguments);
    await this.menu.show(this);
  }

  @action
  async onPointerMove(event) {
    if (this.expanded && this.trigger.contains(event.target)) {
      return;
    }

    await this.onTrigger(event);
  }

  @action
  async onClick(event) {
    if (this.expanded && this.untriggers.includes("click")) {
      return await this.onUntrigger(event);
    }

    await this.onTrigger(event);
  }

  @action
  async onPointerLeave(event) {
    if (this.untriggers.includes("hover")) {
      await this.onUntrigger(event);
    }
  }

  @action
  async onTrigger() {
    await this.options.beforeTrigger?.(this);
    await this.show();
  }

  @action
  async onUntrigger() {
    await this.close();
  }

  @action
  destroy() {
    this.close();
    this.tearDownListeners();
  }
}
