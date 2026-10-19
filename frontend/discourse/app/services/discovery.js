import Service, { service } from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";

/**
 * The discovery service acts as a 'public API' for our discovery
 * routes. Themes/plugins can use this service as a stable way
 * to learn information about the current route.
 */
@disableImplicitInjections
export default class DiscoveryService extends Service {
  @service router;

  get onDiscoveryRoute() {
    const { currentRouteName } = this.router;
    return (
      currentRouteName?.startsWith("discovery.") ||
      currentRouteName?.startsWith("tags.show") ||
      currentRouteName === "tag.show"
    );
  }

  get category() {
    if (this.onDiscoveryRoute) {
      return this.#routeAttrs?.category;
    }
  }

  get tag() {
    if (this.onDiscoveryRoute) {
      return this.#routeAttrs?.tag;
    }
  }

  get currentTopicList() {
    if (this.onDiscoveryRoute) {
      return this.#routeAttrs?.list;
    }
  }

  /**
   * Which category listing is on screen, for consumers that scope behaviour by
   * page. Undefined anywhere a category listing isn't being rendered.
   *
   * - `"categories"` the categories page
   * - `"subcategories"` a category's subcategories page
   * - `"category"` the subcategories listed above a category's topics
   */
  get categoryListPage() {
    const { currentRouteName } = this.router;

    if (currentRouteName === "discovery.categories") {
      return "categories";
    } else if (currentRouteName === "discovery.subcategories") {
      return "subcategories";
    } else if (this.category) {
      return "category";
    }
  }

  get custom() {
    if (this.onDiscoveryRoute) {
      return this.router.currentRouteName === "discovery.custom";
    }
  }

  get #routeAttrs() {
    return this.router.currentRoute.attributes;
  }
}
