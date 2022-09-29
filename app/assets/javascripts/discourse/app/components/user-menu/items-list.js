import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Session from "discourse/models/session";

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

  async fetchItems() {
    throw new Error(
      `the fetchItems method must be implemented in ${this.constructor.name}`
    );
  }

  async refreshList() {
    await this.#load();
  }

  dismissWarningModal() {
    return null;
  }

  async #load() {
    const cached = this.#getCachedItems();
    if (cached?.length) {
      this.items = cached;
    } else {
      this.loading = true;
    }
    try {
      const items = await this.fetchItems();
      this.#setCachedItems(items);
      this.items = items;
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(
        `an error occurred when loading items for ${this.constructor.name}`,
        err
      );
    } finally {
      this.loading = false;
    }
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
