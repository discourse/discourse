import GlimmerComponent from "discourse/components/glimmer";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Session from "discourse/models/session";

export default class UserMenuItemsList extends GlimmerComponent {
  @tracked loading = false;
  @tracked items = [];

  constructor() {
    super(...arguments);
    this._load();
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

  get itemComponent() {
    throw new Error(
      `the itemComponent property must be implemented in ${this.constructor.name}`
    );
  }

  fetchItems() {
    throw new Error(
      `the fetchItems method must be implemented in ${this.constructor.name}`
    );
  }

  refreshList() {
    this._load();
  }

  dismissWarningModal() {
    return null;
  }

  _load() {
    const cached = this._getCachedItems();
    if (cached?.length) {
      this.items = cached;
    } else {
      this.loading = true;
    }
    this.fetchItems()
      .then((items) => {
        this._setCachedItems(items);
        this.items = items;
      })
      .finally(() => (this.loading = false));
  }

  _getCachedItems() {
    const key = this.itemsCacheKey;
    if (key) {
      return Session.currentProp(`user-menu-items:${key}`);
    }
  }

  _setCachedItems(newItems) {
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
