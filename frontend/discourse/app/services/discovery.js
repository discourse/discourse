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
   * True when the categories on screen are a single category's subcategories
   * listed above its topics, rather than a full category listing.
   */
  get showingSubcategoryList() {
    return (
      !!this.category &&
      this.router.currentRouteName !== "discovery.subcategories"
    );
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
