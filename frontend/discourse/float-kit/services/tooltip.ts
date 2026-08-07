import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { trackedSet } from "@ember/reactive/collections";
import { schedule } from "@ember/runloop";
import Service from "@ember/service";
import type {
  FloatKitTrigger,
  TooltipOptions,
} from "discourse/float-kit/lib/constants";
import DTooltipInstance from "discourse/float-kit/lib/d-tooltip-instance";

/**
 * The service that shows tooltips imperatively, outside the `<DTooltip />`
 * component. It tracks every registered tooltip, enforces that only one tooltip
 * per `identifier` is open at a time, and exposes the set that `DTooltips`
 * renders at the app root. Prefer `<DTooltip />` when a template can own the
 * trigger and content directly.
 */
export default class Tooltip extends Service {
  registeredTooltips = trackedSet<DTooltipInstance>();

  /**
   * Render a tooltip.
   *
   * @param triggerOrInstance - the element that triggered the tooltip (may also be an
   *   object implementing `getBoundingClientRect`), or an existing tooltip instance.
   * @param options - the tooltip options; each field is documented on {@link TooltipOptions}.
   *
   * @returns the shown tooltip instance, or `undefined` when the call is a no-op.
   */
  @action
  async show(
    triggerOrInstance: FloatKitTrigger | DTooltipInstance,
    options?: Partial<TooltipOptions>
  ) {
    let instance: DTooltipInstance | undefined;

    if (triggerOrInstance instanceof DTooltipInstance) {
      instance = triggerOrInstance;

      if (instance.expanded) {
        return;
      }
    } else {
      instance = [...this.registeredTooltips].find(
        (registeredTooltips) => registeredTooltips.trigger === triggerOrInstance
      );
      if (!instance) {
        instance = new DTooltipInstance(getOwner(this)!, options);
        instance.trigger = triggerOrInstance;
        instance.detachedTrigger = true;
      }
    }

    if (instance.options.identifier) {
      for (const tooltip of this.registeredTooltips) {
        if (
          tooltip.options.identifier === instance.options.identifier &&
          tooltip !== instance
        ) {
          await this.close(tooltip);
        }
      }
    }

    if (instance.expanded) {
      await this.close(instance);
      return;
    }

    if (!this.registeredTooltips.has(instance)) {
      this.registeredTooltips.add(instance);
    }

    instance.expanded = true;

    await new Promise((resolve) =>
      // cast away resolve's value parameter: `schedule`'s typed rest args would
      // otherwise demand it be passed here, and the afterRender queue calls it with none.
      schedule("afterRender", resolve as () => void)
    );

    return instance;
  }

  /**
   * Closes the given tooltip.
   *
   * @param tooltip - the tooltip to close, either an instance or an identifier.
   */
  @action
  async close(tooltip?: DTooltipInstance | string) {
    if (typeof tooltip === "string") {
      tooltip = [...this.registeredTooltips].find(
        (registeredTooltip) => registeredTooltip.options.identifier === tooltip
      );
    }

    if (!tooltip) {
      return;
    }

    tooltip.expanded = false;

    if (this.registeredTooltips.has(tooltip)) {
      this.registeredTooltips.delete(tooltip);
    }

    await new Promise((resolve) =>
      schedule("afterRender", resolve as () => void)
    );
  }

  /**
   * Registers event listeners on a trigger to show a tooltip.
   *
   * @param trigger - the element that triggered the tooltip (may also be an object
   *   implementing `getBoundingClientRect`).
   * @param options - see `show`.
   *
   * @returns the created tooltip instance.
   */
  @action
  register(trigger: FloatKitTrigger, options: Partial<TooltipOptions> = {}) {
    const instance = new DTooltipInstance(getOwner(this)!, {
      ...options,
      listeners: true,
    });
    instance.trigger = trigger;
    instance.detachedTrigger = true;
    return instance;
  }
}
