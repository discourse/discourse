import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/application";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import Service from "@ember/service";
import DMenuInstance from "float-kit/lib/d-menu-instance";

export default class Menu extends Service {
  @tracked registeredMenus = [];

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

      if (instance.expanded) {
        return;
      }
    } else {
      instance = this.registeredMenus.find(
        (registeredMenu) => registeredMenu.trigger === arguments[0]
      );

      if (!instance) {
        instance = new DMenuInstance(getOwner(this), arguments[1]);
        instance.trigger = arguments[0];
        instance.detachedTrigger = true;
      }
    }

    if (instance.options.identifier) {
      for (const menu of this.registeredMenus) {
        if (
          menu.options.identifier === instance.options.identifier &&
          menu !== instance
        ) {
          await this.close(menu);
        }
      }
    }

    if (instance.expanded) {
      return await this.close(instance);
    }

    await new Promise((resolve) => {
      if (!this.registeredMenus.includes(instance)) {
        this.registeredMenus = this.registeredMenus.concat(instance);
      }

      instance.expanded = true;

      schedule("afterRender", () => {
        resolve();
      });
    });

    return instance;
  }

  /**
   * Closes the active menu
   * @param {DMenuInstance} [menu] - the menu to close, if not provider will close any active menu
   */
  @action
  async close(menu) {
    if (typeof menu === "string") {
      menu = this.registeredMenus.find(
        (registeredMenu) => registeredMenu.options.identifier === menu
      );
    }

    if (!menu) {
      return;
    }

    await new Promise((resolve) => {
      menu.expanded = false;

      this.registeredMenus = this.registeredMenus.filter(
        (registeredMenu) => menu.id !== registeredMenu.id
      );

      schedule("afterRender", () => {
        resolve();
      });
    });
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
    const instance = new DMenuInstance(getOwner(this), {
      ...options,
      listeners: true,
    });
    instance.trigger = trigger;
    instance.detachedTrigger = true;
    return instance;
  }
}
