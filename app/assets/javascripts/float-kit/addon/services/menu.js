import Service from "@ember/service";
import { getOwner } from "@ember/application";
import { action } from "@ember/object";
import DMenuInstance from "float-kit/lib/d-menu-instance";
import { guidFor } from "@ember/object/internals";
import { tracked } from "@glimmer/tracking";
import { updatePosition } from "float-kit/lib/update-position";

export default class Menu extends Service {
  @tracked activeMenu;
  @tracked portalOutletElement;

  /**
   * Render a menu
   *
   * @param {Element | DMenuInstance}
   *  - trigger - the element that triggered the menu, can also be an object implementing `getBoundingClientRect`
   *  - menu - an instance of a menu
   * @param {Object} [options] - options
   * @param {String | Element | Component} [options.content] - Specifies the content of the menu
   * @param {Integer} [options.maxWidth] - Specifies the maximum width of the content
   * @param {Object} [options.data] - An object which will be passed as the `@data` argument when content is a `Component`
   * @param {Boolean} [options.arrow] - Determines if the menu has an arrow
   * @param {Boolean} [options.offset] - Displaces the content from its reference trigger in pixels
   * @param {String} [options.identifier] - Add a data-identifier attribute to the trigger and the content
   * @param {Boolean} [options.inline] - Improves positioning for trigger that spans over multiple lines
   *
   * @returns {Promise<DMenuInstance>}
   */
  @action
  async show() {
    let instance;

    if (arguments[0] instanceof DMenuInstance) {
      instance = arguments[0];

      if (this.activeMenu === instance && this.activeMenu.expanded) {
        return;
      }
    } else {
      const trigger = arguments[0];
      if (
        this.activeMenu &&
        this.activeMenu.id ===
          (trigger?.id?.length ? trigger.id : guidFor(trigger)) &&
        this.activeMenu.expanded
      ) {
        this.activeMenu?.close();
        return;
      }

      instance = new DMenuInstance(getOwner(this), trigger, arguments[1]);
    }

    await this.replace(instance);
    instance.expanded = true;
    return instance;
  }

  /**
   * Replaces any active menu-
   */
  @action
  async replace(menu) {
    await this.activeMenu?.close();
    this.activeMenu = menu;
  }

  /**
   * Closes the active menu
   * @param {DMenuInstance} [menu] - the menu to close, if not provider will close any active menu
   */
  @action
  async close(menu) {
    if (this.activeMenu && menu && this.activeMenu.id !== menu.id) {
      return;
    }

    await this.activeMenu?.close();
    this.activeMenu = null;
  }

  /**
   * Update the menu position
   * @param {DMenuInstance} [menu] - the menu to update, if not provider will update any active menu
   */
  @action
  async update(menu) {
    const instance = menu || this.activeMenu;
    if (!instance) {
      return;
    }
    await updatePosition(instance.trigger, instance.content, instance.options);
    await instance.show();
  }

  /**
   * Register event listeners on a trigger to show a menu
   *
   * @param {Element} trigger - the element that triggered the menu, can also be an object implementing `getBoundingClientRect`
   * @param {Object} [options] - @see `show`
   *
   * @returns {DMenuInstance} An instance of the menu
   */
  @action
  register(trigger, options = {}) {
    return new DMenuInstance(getOwner(this), trigger, {
      ...options,
      listeners: true,
      beforeTrigger: async (menu) => {
        await this.replace(menu);
      },
    });
  }

  @action
  registerPortalOutletElement(element) {
    this.portalOutletElement = element;
  }
}
