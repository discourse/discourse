import I18n from "I18n";
import Session from "discourse/models/session";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { headerHeight } from "discourse/components/site-header";
import { Promise } from "rsvp";

// even a 2 liner notification should be under 50px in default view
const AVERAGE_ITEM_HEIGHT = 50;

// our UX usually carries about 100px of padding around the notification excluding header
const PADDING = 100;

/**
 * This tries to enforce a consistent flow of fetching, caching, refreshing,
 * and rendering for "quick access items".
 *
 * There are parts to introducing a new quick access panel:
 * 1. A user menu link that sends a `quickAccess` action, with a unique `type`.
 * 2. A `quick-access-${type}` widget, extended from `quick-access-panel`.
 */
export default createWidget("quick-access-panel", {
  tagName: "div.quick-access-panel",
  emptyStatePlaceholderItemKey: "",

  buildKey: () => {
    throw Error('Cannot attach abstract widget "quick-access-panel".');
  },

  markReadRequest() {
    return Promise.resolve();
  },

  hasUnread() {
    return false;
  },

  showAllHref() {
    return "";
  },

  hasMore() {
    return true;
  },

  findNewItems() {
    return Promise.resolve([]);
  },

  newItemsLoaded() {},

  itemHtml(item) {}, // eslint-disable-line no-unused-vars

  emptyStatePlaceholderItem() {
    if (this.emptyStatePlaceholderItemKey) {
      return h("li.read", I18n.t(this.emptyStatePlaceholderItemKey));
    } else {
      return "";
    }
  },

  defaultState() {
    return { items: [], loading: false, loaded: false };
  },

  markRead() {
    return this.markReadRequest().then(() => {
      this.refreshNotifications(this.state);
    });
  },

  estimateItemLimit() {
    return 40;
  },

  refreshNotifications(state) {
    if (this.loading) {
      return;
    }

    if (this.getItems().length === 0) {
      state.loading = true;
    }

    this.findNewItems()
      .then(newItems => this.setItems(newItems))
      .catch(() => this.setItems([]))
      .finally(() => {
        state.loading = false;
        state.loaded = true;
        this.newItemsLoaded();
        this.sendWidgetAction("itemsLoaded", {
          hasUnread: this.hasUnread(),
          markRead: () => this.markRead()
        });
        this.scheduleRerender();
      });
  },

  html(attrs, state) {
    if (!state.loaded) {
      this.refreshNotifications(state);
    }

    if (state.loading) {
      return [h("div.spinner-container", h("div.spinner"))];
    }

    let bottomItems = [];
    const items = this.getItems().length
      ? this.getItems().map(item => this.itemHtml(item))
      : [this.emptyStatePlaceholderItem()];

    if (this.hasMore()) {
      bottomItems.push(
        h(
          "span.show-all",
          this.attach("button", {
            title: "view_all",
            icon: "chevron-down",
            url: this.showAllHref()
          })
        )
      );
    }

    if (this.hasUnread()) {
      bottomItems.push(
        h(
          "span.dismiss",
          this.attach("button", {
            title: "user.dismiss_notifications_tooltip",
            icon: "check",
            label: "user.dismiss",
            action: "dismissNotifications"
          })
        )
      );
    }

    return [h("ul", items), h("div.panel-body-bottom", bottomItems)];
  },

  getItems() {
    return Session.currentProp(`${this.key}-items`) || [];
  },

  setItems(newItems) {
    Session.currentProp(`${this.key}-items`, newItems);
  }
});
