import { registerDestructor } from "@ember/destroyable";
import { guidFor } from "@ember/object/internals";
import type Owner from "@ember/owner";
import { service } from "@ember/service";
import Modifier, { type ArgsFor } from "ember-modifier";
import type { MenuOptions } from "discourse/float-kit/lib/constants";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import type MenuService from "discourse/float-kit/services/menu";
import isContextMenuExemptTarget from "discourse/lib/is-context-menu-exempt-target";
import virtualElementFromPoint from "discourse/lib/virtual-element-from-point";

interface FloatKitContextMenuSignature {
  Element: HTMLElement;
  Args: {
    Positional: [];
    Named: Partial<MenuOptions> & {
      /** The menu content, receiving `@data` and `@close`. */
      component: NonNullable<MenuOptions["component"]>;

      /**
       * Decides synchronously whether to replace the native menu. Return `false` to leave
       * the event untouched, `true` to accept, or options to accept and override named options.
       * When omitted, targets that own a text caret keep their native menu.
       */
      beforeContextMenu?: (event: MouseEvent) => boolean | Partial<MenuOptions>;
    };
  };
}

/** Opens a menu at the right-click's viewport point and owns its lifetime. */
export default class FloatKitContextMenu extends Modifier<FloatKitContextMenuSignature> {
  @service declare menu: MenuService;

  #identifier = `context-menu-${guidFor(this)}`;
  #disposed = false;
  #instance: DMenuInstance | undefined;
  #pendingOpen: Promise<void> = Promise.resolve();
  #removeListener: (() => void) | undefined;

  constructor(owner: Owner, args: ArgsFor<FloatKitContextMenuSignature>) {
    super(owner, args);
    registerDestructor(this, () => {
      this.#disposed = true;
      this.#removeListener?.();
      this.menu.close(this.#instance);
    });
  }

  modify(
    element: HTMLElement,
    _positional: [],
    {
      beforeContextMenu,
      ...options
    }: FloatKitContextMenuSignature["Args"]["Named"]
  ) {
    this.#removeListener?.();

    const onContextMenu = (event: MouseEvent) => {
      const decision = beforeContextMenu
        ? beforeContextMenu(event)
        : !isContextMenuExemptTarget(event.target);

      if (
        decision !== true &&
        (!decision || typeof decision !== "object" || "then" in decision)
      ) {
        return;
      }

      event.preventDefault();
      event.stopPropagation();

      const menuOptions = {
        ...options,
        ...(typeof decision === "object" ? decision : {}),
      };
      menuOptions.identifier ||= this.#identifier;
      const reference = virtualElementFromPoint(event.clientX, event.clientY);

      // The service can yield while replacing an existing menu. Serialize opens so rapid
      // gestures cannot register multiple replacements while that close is pending. The chain
      // must never settle rejected: a rejected promise skips every later `then`, which would
      // leave the element silently unable to open a menu again.
      this.#pendingOpen = this.#pendingOpen
        .then(() => this.#open(reference, menuOptions))
        .catch(() => {});
    };

    element.addEventListener("contextmenu", onContextMenu);
    this.#removeListener = () =>
      element.removeEventListener("contextmenu", onContextMenu);
  }

  async #open(
    reference: ReturnType<typeof virtualElementFromPoint>,
    options: Partial<MenuOptions>
  ): Promise<void> {
    if (this.#disposed) {
      return;
    }

    if (
      this.#instance &&
      this.#instance.options.identifier !== options.identifier
    ) {
      await this.menu.close(this.#instance);
      if (this.#disposed) {
        return;
      }
    }

    const instance = await this.menu.show(reference, options);
    if (this.#disposed) {
      await this.menu.close(instance);
    } else {
      this.#instance = instance;
    }
  }
}
