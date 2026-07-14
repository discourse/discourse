import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import Owner, { setOwner } from "@ember/owner";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import {
  type FloatKitTrigger,
  TOOLTIP,
  type TooltipOptions,
} from "discourse/float-kit/lib/constants";
import FloatKitInstance from "discourse/float-kit/lib/float-kit-instance";
import type TooltipService from "discourse/float-kit/services/tooltip";

/**
 * The concrete float instance backing a tooltip. It holds the tooltip's options,
 * open/close state, and portal outlet, and implements the trigger and lifecycle
 * hooks that `FloatKitInstance` orchestrates.
 */
export default class DTooltipInstance extends FloatKitInstance {
  @service declare tooltip: TooltipService;

  /** Whether the tooltip is currently open. */
  @tracked expanded = false;

  /**
   * Whether the tooltip's trigger is managed outside the `<DTooltip />`
   * component. It is set when the tooltip is created through the `tooltip`
   * service, where the trigger and content live in separate parts of the DOM
   * and are rendered by `DHeadlessTooltip` rather than by `DTooltip`.
   */
  @tracked detachedTrigger = false;

  /**
   * The merged tooltip options: the defaults from `TOOLTIP.options` with the
   * caller's overrides applied in the constructor.
   */
  @tracked options: TooltipOptions;
  @tracked portalOutletOverrideElement?: HTMLElement | null;

  @tracked _trigger: FloatKitTrigger;

  constructor(owner: Owner, options: Partial<TooltipOptions> = {}) {
    super();

    setOwner(this, owner);
    this.options = { ...TOOLTIP.options, ...options };
    this.portalOutletOverrideElement = options.portalOutletElement;
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

  get portalOutletElement() {
    return (
      this.portalOutletOverrideElement ||
      document.getElementById("d-tooltip-portals")
    );
  }

  @action
  async show() {
    await this.tooltip.show(this);
    await super.show();
  }

  @action
  async close() {
    this.openedByDelayedHover = false;
    await this.tooltip.close(this);

    await super.close();
  }

  @action
  async onPointerMove(event: PointerEvent) {
    if (
      this.expanded &&
      this.triggerElement?.contains(event.target as Node) &&
      event.pointerType !== "touch"
    ) {
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
  // the trigger event is relayed in from the base and shared actions but, unlike a
  // menu, a tooltip does not stop its propagation, so the argument is unused here.
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async onTrigger(_event?: Event) {
    await this.options.beforeTrigger?.(this);
    await this.show();
  }

  @action
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async onUntrigger(_event?: Event) {
    await this.close();
  }

  @action
  destroy() {
    this.close();
    this.tearDownListeners();
  }
}
