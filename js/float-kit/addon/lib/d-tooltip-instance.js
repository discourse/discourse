import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { TOOLTIP } from "float-kit/lib/constants";
import FloatKitInstance from "float-kit/lib/float-kit-instance";

export default class DTooltipInstance extends FloatKitInstance {
  @service tooltip;

  /**
   * Indicates whether the tooltip is expanded or not.
   * @property {boolean} expanded - Tracks the state of tooltip expansion, initially set to false.
   */
  @tracked expanded = false;

  /**
   * Specifies whether the trigger for opening/closing the tooltip is detached from the tooltip itself.
   * This is the case when a tooltip is trigger programmatically instead of through the <DTooltip /> component.
   * @property {boolean} detachedTrigger - Tracks whether the trigger is detached, initially set to false.
   */
  @tracked detachedTrigger = false;

  /**
   * Configuration options for the DTooltipInstance.
   * @property {Object} options - Options object that configures the tooltip behavior and display.
   */
  @tracked options;

  @tracked _trigger;

  constructor(owner, options = {}) {
    super(...arguments);

    setOwner(this, owner);
    this.options = { ...TOOLTIP.options, ...options };
  }

  get trigger() {
    return this._trigger;
  }

  set trigger(element) {
    this._trigger = element;
    this.id = element.id || guidFor(element);
    this.setupListeners();
  }

  get portalOutletElement() {
    return document.getElementById("d-tooltip-portals");
  }

  @action
  async show() {
    await this.tooltip.show(this);
    await super.show(...arguments);
  }

  @action
  async close() {
    await this.tooltip.close(this);

    await super.close(...arguments);
  }

  @action
  async onPointerMove(event) {
    if (
      this.expanded &&
      this.trigger.contains(event.target) &&
      event.pointerType !== "touch"
    ) {
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
