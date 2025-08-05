import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";

/**
 * Service for managing the "last forum URL" across different modes
 * (chat & AI conversations). Ensures that when users click "back to forum"
 * they go to actual forum content and don't loop between modes.
 */
export default class LastForumUrl extends Service {
  @service router;

  @tracked _lastForumURL = null;

  /**
   * Store the current URL as the last forum URL if it's not a different mode
   * @param {string|null} url - Optional URL to store, defaults to current URL
   */
  storeUrl(url = null) {
    const urlToStore = url || this.router.currentURL;

    if (urlToStore && !this._isSpecialMode(urlToStore)) {
      this._lastForumURL = urlToStore;
    }
  }

  /**
   * Get the last known forum URL
   * @returns {string} The last forum URL
   */
  get url() {
    if (this._lastForumURL && this._lastForumURL !== "/") {
      return this._lastForumURL;
    }

    return this.router.urlFor(`discovery.${defaultHomepage()}`);
  }

  /**
   * Check if a URL belongs to a mode that shouldn't be stored as forum URL
   * @param {string} url - The URL to check
   * @returns {boolean} True if the URL is from a specific mode
   * @private
   */
  _isSpecialMode(url) {
    const modePrefixes = ["/chat", "/discourse-ai/ai-bot"];
    return modePrefixes.some((prefix) => url.startsWith(prefix));
  }
}
