import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

// Core's own sign-in pages, which keep core's minimal header and nothing else.
const AUTH_ROUTES = ["login", "signup", "discovery.login-required"];

/**
 * Works out which channel the current page belongs to, for everything that
 * changes with it (the header row, the member list).
 *
 * Outside channels, the site-wide pages from the server menu get a title of
 * their own.
 */
export default class CurrentChannel {
  @service discovery;
  @service router;

  constructor(owner) {
    setOwner(this, owner);
    this.chat = owner.lookup("service:chat");
    this.voiceRooms = owner.lookup("service:live-rooms");
  }

  // Admin keeps to its own pages, so the header leaves out what's for
  // channels and offers a way back instead.
  get isAdmin() {
    return (this.router.currentRouteName || "").startsWith("admin");
  }

  get isAuthPage() {
    return AUTH_ROUTES.includes(this.router.currentRouteName);
  }

  /**
   * @returns {{ type: "text", channel } | { type: "voice", room } |
   *   { type: "forum", category } | { type: "topic", topic } |
   *   { type: "tag", tag } | { type: "page", icon, name, description? } |
   *   undefined}
   */
  get value() {
    const name = this.router.currentRouteName || "";

    if (name.startsWith("chat.channel")) {
      const channel = this.chat?.activeChannel;
      return channel && { type: "text", channel };
    }

    if (name.startsWith("topic.")) {
      const topic = this.#routeAttributes("topic");
      return topic && { type: "topic", topic };
    }

    if (name === "live-room") {
      const room = this.voiceRooms?.roomBySlug(
        this.router.currentRoute.params.slug
      );
      return room && { type: "voice", room };
    }

    if (this.discovery.category) {
      return { type: "forum", category: this.discovery.category };
    }

    if (this.discovery.tag) {
      return { type: "tag", tag: this.discovery.tag };
    }

    return this.#page(name);
  }

  // The same names and icons as the server menu, which takes them from core's
  // community section links.
  #page(name) {
    const page = (link, icon) => ({
      type: "page",
      icon,
      name: i18n(`sidebar.sections.community.links.${link}.content`),
    });

    if (name === "about") {
      return page("about", "circle-info");
    }
    if (name === "faq" || name === "guidelines") {
      return page(name, "circle-question");
    }
    if (name.startsWith("groups.")) {
      return page("groups", "user-group");
    }
    // Named the way the group page names it, with the @name underneath when
    // it has a full name.
    if (name.startsWith("group.")) {
      const group = this.#routeAttributes("group");
      if (!group) {
        return;
      }

      const title = group.full_name || group.display_name || group.name;
      return {
        type: "page",
        icon: "user-group",
        name: title,
        description: title === group.name ? null : `@${group.name}`,
      };
    }
    if (name === "users") {
      return page("users", "users");
    }
    if (name === "badges.index") {
      return page("badges", "certificate");
    }
    if (name === "badges.show") {
      const badge = this.#routeAttributes("badges.show");
      return (
        badge && {
          ...page("badges", "certificate"),
          name: badge.name,
          description: page("badges").name,
        }
      );
    }
    if (name === "review" || name.startsWith("review.")) {
      return page("review", "flag");
    }
    if (name.startsWith("admin")) {
      return page("admin", "wrench");
    }
  }

  #routeAttributes(routeName) {
    let route = this.router.currentRoute;

    while (route) {
      if (route.name === routeName) {
        return route.attributes;
      }
      route = route.parent;
    }
  }
}
