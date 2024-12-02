import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import Service from "@ember/service";
import { TrackedSet } from "tracked-built-ins";
import DMenuInstance from "float-kit/lib/d-menu-instance";

export default class Menu extends Service {
  registeredMenus = new TrackedSet();

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
   * @param {String} [options.identifier] - Add a data-identifier attribute to the trigger and the content, multiple menus can have the same identifier,
   * only one menu with the same identifier can be open at a time
   * @param {String} [options.groupIdentifier] - Only one menu with the same groupIdentifier can be open at a time
   * @param {Boolean} [options.inline] - Improves positioning for trigger that spans over multiple lines
   *
   * @returns {Promise<DMenuInstance | undefined>}
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
      instance = [...this.registeredMenus].find(
        (registeredMenu) => registeredMenu.trigger === arguments[0]
      );

      if (!instance) {
        instance = new DMenuInstance(getOwner(this), arguments[1]);
        instance.trigger = arguments[0];
        instance.detachedTrigger = true;
      }
    }

    if (instance.options.identifier || instance.options.groupIdentifier) {
      for (const registeredMenu of this.registeredMenus) {
        if (
          ((instance.options.identifier &&
            registeredMenu.options.identifier ===
              instance.options.identifier) ||
            (instance.options.groupIdentifier &&
              registeredMenu.options.groupIdentifier ===
                instance.options.groupIdentifier)) &&
          registeredMenu !== instance
        ) {
          await this.close(registeredMenu);
        }
      }
    }

    if (instance.expanded) {
      await this.close(instance);
      return;
    }

    if (!this.registeredMenus.has(instance)) {
      this.registeredMenus.add(instance);
    }

    instance.expanded = true;

    await new Promise((resolve) => schedule("afterRender", resolve));

    return instance;
  }

  /**
   * Returns an existing menu by its identifier if found
   *
   * @param {String} identifier - the menu identifier to retrieve
   *
   * @returns {DMenuInstance | undefined}
   */
  getByIdentifier(identifier) {
    return [...this.registeredMenus].find(
      (registeredMenu) => registeredMenu.options.identifier === identifier
    );
  }

  /**
   * Closes the given menu
   *
   * @param {DMenuInstance | String} [menu | identifier] - the menu to close, can accept an instance or an identifier
   */
  @action
  async close(menu) {
    if (typeof menu === "string") {
      menu = [...this.registeredMenus].find(
        (registeredMenu) => registeredMenu.options.identifier === menu
      );
    }

    if (!menu) {
      return;
    }

    menu.expanded = false;

    if (this.registeredMenus.has(menu)) {
      this.registeredMenus.delete(menu);
    }

    await new Promise((resolve) => schedule("afterRender", resolve));
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
