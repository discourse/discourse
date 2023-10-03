import Service from "@ember/service";
import { getOwner } from "@ember/application";
import { action } from "@ember/object";
import DTooltipInstance from "float-kit/lib/d-tooltip-instance";
import { guidFor } from "@ember/object/internals";
import { tracked } from "@glimmer/tracking";
import { updatePosition } from "float-kit/lib/update-position";

export default class Tooltip extends Service {
  @tracked activeTooltip;
  @tracked portalOutletElement;

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
   * @returns {Promise<DTooltipInstance>}
   */
  @action
  async show() {
    let instance;

    if (arguments[0] instanceof DTooltipInstance) {
      instance = arguments[0];

      if (this.activeTooltip === instance && this.activeTooltip.expanded) {
        return;
      }
    } else {
      const trigger = arguments[0];
      if (
        this.activeTooltip &&
        this.activeTooltip.id ===
          (trigger?.id?.length ? trigger.id : guidFor(trigger)) &&
        this.activeTooltip.expanded
      ) {
        this.activeTooltip?.close();
        return;
      }

      instance = new DTooltipInstance(getOwner(this), trigger, arguments[1]);
    }

    await this.replace(instance);
    instance.expanded = true;
    return instance;
  }

  /**
   * Replaces any active tooltip
   */
  @action
  async replace(tooltip) {
    await this.activeTooltip?.close();
    this.activeTooltip = tooltip;
  }

  /**
   * Closes the active tooltip
   * @param {DTooltipInstance} [tooltip] - the tooltip to close, if not provider will close any active tooltip
   */
  @action
  async close(tooltip) {
    if (this.activeTooltip && tooltip && this.activeTooltip.id !== tooltip.id) {
      return;
    }

    await this.activeTooltip?.close();
    this.activeTooltip = null;
  }

  /**
   * Update the tooltip position
   * @param {DTooltipInstance} [tooltip] - the tooltip to update, if not provider will update any active tooltip
   */
  @action
  async update(tooltip) {
    const instance = tooltip || this.activeTooltip;
    if (!instance) {
      return;
    }
    await updatePosition(instance.trigger, instance.content, instance.options);
    await instance.show();
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
    return new DTooltipInstance(getOwner(this), trigger, {
      ...options,
      listeners: true,
      beforeTrigger: async (tooltip) => {
        await this.replace(tooltip);
      },
    });
  }

  @action
  registerPortalOutletElement(element) {
    this.portalOutletElement = element;
  }
}
