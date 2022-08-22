import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Session from "discourse/models/session";
import { findUserMenuItemRenderer } from "discourse/lib/user-menu/item-renderers-manager";
import { findUserMenuListProcessors } from "discourse/lib/user-menu/list-processors-manager";
import { allSettled } from "rsvp";

export default class UserMenuItemsList extends Component {
  @tracked loading = false;
  @tracked items = [];

  constructor() {
    super(...arguments);
    this.#load();
  }

  get itemsCacheKey() {}

  get showAllHref() {}

  get showAllTitle() {}

  get showDismiss() {
    return false;
  }

  get dismissTitle() {}

  get emptyStateComponent() {
    return "user-menu/items-list-empty-state";
  }

  fetchItems() {
    throw new Error(
      `the fetchItems method must be implemented in ${this.constructor.name}`
    );
  }

  findItemRendererClass(type) {
    return findUserMenuItemRenderer(type);
  }

  applyListProcessorsFromPlugins(listType, list) {
    return allSettled(
      findUserMenuListProcessors(listType).map((processor) => {
        return processor(list);
      })
    );
  }

  refreshList() {
    this.#load();
  }

  dismissWarningModal() {
    return null;
  }

  #load() {
    const cached = this.#getCachedItems();
    if (cached?.length) {
      this.items = cached;
    } else {
      this.loading = true;
    }
    this.fetchItems()
      .then((items) => {
        this.#setCachedItems(items);
        this.items = items;
      })
      .finally(() => (this.loading = false));
  }

  #getCachedItems() {
    const key = this.itemsCacheKey;
    if (key) {
      return Session.currentProp(`user-menu-items:${key}`);
    }
  }

  #setCachedItems(newItems) {
    const key = this.itemsCacheKey;
    if (key) {
      Session.currentProp(`user-menu-items:${key}`, newItems);
    }
  }

  @action
  dismissButtonClick() {
    throw new Error(
      `dismissButtonClick must be implemented in ${this.constructor.name}.`
    );
  }
}
