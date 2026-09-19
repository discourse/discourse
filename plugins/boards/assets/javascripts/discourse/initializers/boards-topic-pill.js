import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";
import BoardsMenu from "../components/boards-menu";
import {
  boardsTagsHtml,
  membershipsFor,
  MULTI_BOARD_TRIGGER_SELECTOR,
} from "../lib/boards-topic-pill";

/**
 * Topic pills are rendered as tags, as raw HTML, so there is no component to
 * hang a click handler on. Boards are delegated from the app root the way
 * discourse-local-dates opens its date popover.
 */
class BoardsTopicPills {
  @service menu;

  // keyed by the trigger, so a menu is built once per pill and goes away with it
  #menus = new WeakMap();

  constructor(owner) {
    setOwner(this, owner);

    withPluginApi((api) => api.addTagsHtmlCallback(boardsTagsHtml));

    this.rootElement = document.querySelector(owner.rootElement);
    this.rootElement?.addEventListener("click", this.onClick);
    this.rootElement?.addEventListener("keydown", this.onKeydown);
  }

  @bind
  onClick(event) {
    return this.#toggleMenu(event);
  }

  @bind
  onKeydown(event) {
    if (event.key === "Enter" || event.key === " ") {
      return this.#toggleMenu(event);
    }
  }

  teardown() {
    this.rootElement?.removeEventListener("click", this.onClick);
    this.rootElement?.removeEventListener("keydown", this.onKeydown);
    this.rootElement = null;
  }

  #toggleMenu(event) {
    const trigger = event.target.closest(MULTI_BOARD_TRIGGER_SELECTOR);
    if (!trigger) {
      return;
    }

    event.preventDefault();

    const instance = this.#menuFor(trigger);
    return instance.expanded ? instance.close() : instance.show();
  }

  #menuFor(trigger) {
    let instance = this.#menus.get(trigger);

    if (!instance) {
      instance = this.menu.newInstance(trigger, {
        identifier: "discourse-boards-topic-pill",
        component: BoardsMenu,
        modalForMobile: true,
        data: { memberships: membershipsFor(trigger) },
        onShow: () => trigger.setAttribute("aria-expanded", "true"),
        onClose: () => trigger.setAttribute("aria-expanded", "false"),
      });
      this.#menus.set(trigger, instance);
    }

    return instance;
  }
}

export default {
  name: "discourse-boards-topic-pill",

  initialize(_container, owner) {
    this.instance = new BoardsTopicPills(owner);
  },

  teardown() {
    this.instance?.teardown();
    this.instance = null;
  },
};
