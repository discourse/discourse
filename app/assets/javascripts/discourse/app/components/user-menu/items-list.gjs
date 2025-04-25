import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class UserMenuItemsList extends Component {
  @service session;

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

  get renderDismissConfirmation() {
    return false;
  }

  async fetchItems() {
    throw new Error(
      `the fetchItems method must be implemented in ${this.constructor.name}`
    );
  }

  async refreshList() {
    await this.#load();
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
      return this.session[`user-menu-items:${key}`];
    }
  }

  #setCachedItems(newItems) {
    const key = this.itemsCacheKey;
    if (key) {
      this.session.set(`user-menu-items:${key}`, newItems);
    }
  }

  @action
  dismissButtonClick() {
    throw new Error(
      `dismissButtonClick must be implemented in ${this.constructor.name}.`
    );
  }
}
