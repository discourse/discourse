import Service, { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import updateTabCount from "discourse/lib/update-tab-count";

@disableImplicitInjections
export default class DocumentElement extends Service {
  @service appEvents;
  @service currentUser;
  @service session;
  @service siteSettings;

  contextCount = 0;
  notificationCount = 0;
  #title = null;
  #backgroundNotify = null;

  getTitle() {
    return this.#title;
  }

  setTitle(title) {
    this.#title = title;
    this._renderTitle();
  }

  setFocus(focus) {
    let { session } = this;

    session.hasFocus = focus;

    if (session.hasFocus && this.#backgroundNotify) {
      this.updateContextCount(0);
    }
    this.#backgroundNotify = false;

    if (session.hasFocus) {
      this.notificationCount = 0;
    }
    this.appEvents.trigger("discourse:focus-changed", session.hasFocus);
    this._renderFavicon();
    this._renderTitle();
  }

  updateContextCount(count) {
    this.contextCount = count;
    this._renderTitle();
  }

  updateNotificationCount(count, { forced = false } = {}) {
    if (!this.session.hasFocus || forced) {
      this.notificationCount = count;
      this._renderFavicon();
      this._renderTitle();
    }
  }

  incrementBackgroundContextCount() {
    if (!this.session.hasFocus) {
      this.#backgroundNotify = true;
      this.contextCount += 1;
      this._renderFavicon();
      this._renderTitle();
    }
  }

  _displayCount() {
    return this.currentUser?.user_option.title_count_mode === "notifications"
      ? this.notificationCount
      : this.contextCount;
  }

  _renderTitle() {
    let title = this.#title || this.siteSettings.title;

    let displayCount = this._displayCount();
    let dynamicFavicon = this.currentUser?.user_option.dynamic_favicon;

    if (this.currentUser?.isInDoNotDisturb()) {
      document.title = title;
      return;
    }

    if (displayCount > 0 && !dynamicFavicon) {
      title = `(${displayCount}) ${title}`;
    }

    document.title = title;
  }

  _renderFavicon() {
    if (this.currentUser?.user_option.dynamic_favicon) {
      let url = this.siteSettings.site_favicon_url;

      // Since the favicon is cached on the browser for a really long time, we
      // append the favicon_url as query params to the path so that the cache
      // is not used when the favicon changes.
      if (/^http/.test(url)) {
        url = getURL("/favicon/proxied?" + encodeURIComponent(url));
      }

      updateTabCount(url, this._displayCount());
    }
  }
}
