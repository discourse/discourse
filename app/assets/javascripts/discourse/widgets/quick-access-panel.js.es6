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
    return this.getItems().length >= this.estimateItemLimit();
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
    // Estimate (poorly) the amount of notifications to return.
    let limit = Math.round(
      ($(window).height() - headerHeight() - PADDING) / AVERAGE_ITEM_HEIGHT
    );

    // We REALLY don't want to be asking for negative counts of notifications
    // less than 5 is also not that useful.
    if (limit < 5) {
      limit = 5;
    } else if (limit > 40) {
      limit = 40;
    }

    return limit;
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

    const items = this.getItems().length
      ? this.getItems().map(item => this.itemHtml(item))
      : [this.emptyStatePlaceholderItem()];

    if (this.hasMore()) {
      items.push(
        h(
          "li.read.last.show-all",
          this.attach("link", {
            title: "view_all",
            icon: "chevron-down",
            href: this.showAllHref()
          })
        )
      );
    }

    return [h("ul", items)];
  },

  getItems() {
    return Session.currentProp(`${this.key}-items`) || [];
  },

  setItems(newItems) {
    Session.currentProp(`${this.key}-items`, newItems);
  }
});
