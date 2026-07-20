import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { trackedSet } from "@ember/reactive/collections";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import type {
  FloatKitTrigger,
  MenuOptions,
} from "discourse/float-kit/lib/constants";
import DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import FloatKitInstance from "discourse/float-kit/lib/float-kit-instance";
import type Site from "discourse/models/site";

/**
 * The service that shows menus imperatively, outside the `<DMenu />` component.
 * It tracks every registered menu, enforces that only one menu per `identifier`
 * or `groupIdentifier` is open at a time, and exposes the set that `DMenus`
 * renders at the app root. Prefer `<DMenu />` when a template can own the trigger
 * and content directly.
 */
export default class Menu extends Service {
  @service declare site: Site;

  registeredMenus = trackedSet<DMenuInstance>();

  /**
   * Whether a menu with the given `modalForMobile` option renders as a mobile modal (an
   * `aria-modal` dialog) rather than an inline popover. This is the instance-less accessor a
   * caller uses before a menu exists; it delegates to the shared formula in
   * {@link FloatKitInstance.resolveRenderInModal}, so it can't drift from what `<DMenu>` renders.
   *
   * @param modalForMobile - the menu's `@modalForMobile` option.
   */
  shouldRenderInModal(modalForMobile?: boolean): boolean {
    return FloatKitInstance.resolveRenderInModal(this.site, modalForMobile);
  }

  /**
   * Render a menu.
   *
   * @param triggerOrInstance - the element that triggered the menu (may also be an
   *   object implementing `getBoundingClientRect`), or an existing menu instance.
   * @param options - the menu options; each field is documented on {@link MenuOptions}.
   *
   * @returns the shown menu instance, or `undefined` when the call is a no-op.
   */
  @action
  async show(
    triggerOrInstance: FloatKitTrigger | DMenuInstance,
    options?: Partial<MenuOptions>
  ) {
    let instance: DMenuInstance | undefined;

    if (triggerOrInstance instanceof DMenuInstance) {
      instance = triggerOrInstance;

      if (instance.expanded) {
        return;
      }
    } else {
      instance = [...this.registeredMenus].find(
        (registeredMenu) => registeredMenu.trigger === triggerOrInstance
      );

      instance ??= this.newInstance(triggerOrInstance, options);
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

    await new Promise((resolve) =>
      // cast away resolve's value parameter: `schedule`'s typed rest args would
      // otherwise demand it be passed here, and the afterRender queue calls it with none.
      schedule("afterRender", resolve as () => void)
    );

    return instance;
  }

  /**
   * Creates a menu instance with a detached trigger, without showing it.
   *
   * @param trigger - the element the menu is anchored to (may also be an object
   *   implementing `getBoundingClientRect`).
   * @param options - the menu options; each field is documented on {@link MenuOptions}.
   *
   * @returns the created menu instance.
   */
  newInstance(trigger: FloatKitTrigger, options?: Partial<MenuOptions>) {
    const instance = new DMenuInstance(getOwner(this)!, options);
    instance.trigger = trigger;
    instance.detachedTrigger = true;

    return instance;
  }

  /**
   * Returns an existing menu by its identifier if found.
   *
   * @param identifier - the menu identifier to retrieve.
   */
  getByIdentifier(identifier: string) {
    return [...this.registeredMenus].find(
      (registeredMenu) => registeredMenu.options.identifier === identifier
    );
  }

  /**
   * Closes the given menu.
   *
   * @param menu - the menu to close, either an instance or an identifier.
   */
  @action
  async close(menu?: DMenuInstance | string) {
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

    await new Promise((resolve) =>
      // cast away resolve's value parameter: `schedule`'s typed rest args would
      // otherwise demand it be passed here, and the afterRender queue calls it with none.
      schedule("afterRender", resolve as () => void)
    );
  }

  /**
   * Registers event listeners on a trigger to show a menu.
   *
   * @param trigger - the element that triggered the menu (may also be an object
   *   implementing `getBoundingClientRect`).
   * @param options - see `show`.
   *
   * @returns the created menu instance.
   */
  @action
  register(trigger: FloatKitTrigger, options: Partial<MenuOptions> = {}) {
    const instance = new DMenuInstance(getOwner(this)!, {
      ...options,
      listeners: true,
    });
    instance.trigger = trigger;
    instance.detachedTrigger = true;
    return instance;
  }
}
