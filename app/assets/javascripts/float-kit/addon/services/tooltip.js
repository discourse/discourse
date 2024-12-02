import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import Service from "@ember/service";
import { TrackedSet } from "tracked-built-ins";
import DTooltipInstance from "float-kit/lib/d-tooltip-instance";

export default class Tooltip extends Service {
  registeredTooltips = new TrackedSet();

  /**
   * Render a tooltip
   *
   * @param {Element | DTooltipInstance}
   *  - trigger - the element that triggered the tooltip, can also be an object implementing `getBoundingClientRect`
   *  - tooltip - an instance of a tooltip
   * @param {Object} [options] - options, if trigger given as first argument
   * @param {String | Element | Component} [options.content] - Specifies the content of the tooltip
   * @param {Integer} [options.maxWidth] - Specifies the maximum width of the content
   * @param {Object} [options.data] - An object which will be passed as the `@data` argument when content is a `Component`
   * @param {Boolean} [options.arrow] - Determines if the tooltip has an arrow
   * @param {Boolean} [options.offset] - Displaces the content from its reference trigger in pixels
   * @param {String} [options.identifier] - Add a data-identifier attribute to the trigger and the content
   * @param {Boolean} [options.inline] - Improves positioning for trigger that spans over multiple lines
   *
   * @returns {Promise<DTooltipInstance | undefined>}
   */
  @action
  async show() {
    let instance;

    if (arguments[0] instanceof DTooltipInstance) {
      instance = arguments[0];

      if (instance.expanded) {
        return;
      }
    } else {
      instance = [...this.registeredTooltips].find(
        (registeredTooltips) => registeredTooltips.trigger === arguments[0]
      );
      if (!instance) {
        instance = new DTooltipInstance(getOwner(this), arguments[1]);
        instance.trigger = arguments[0];
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

    await new Promise((resolve) => schedule("afterRender", resolve));

    return instance;
  }

  /**
   * Closes the given tooltip
   * @param {DTooltipInstance | String} [tooltip | identifier] - the tooltip to close, can accept an instance or an identifier
   */
  @action
  async close(tooltip) {
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

    await new Promise((resolve) => schedule("afterRender", resolve));
  }

  /**
   * Register event listeners on a trigger to show a tooltip
   *
   * @param {Element} trigger - the element that triggered the tooltip, can also be an object implementing `getBoundingClientRect`
   * @param {Object} [options] - @see `show`
   *
   * @returns {DTooltipInstance} An instance of the tooltip
   */
  @action
  register(trigger, options = {}) {
    const instance = new DTooltipInstance(getOwner(this), {
      ...options,
      listeners: true,
    });
    instance.trigger = trigger;
    instance.detachedTrigger = true;
    return instance;
  }
}
