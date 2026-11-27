import { cached } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { canDisplayCategory } from "discourse/lib/sidebar/helpers";
import Category from "discourse/models/category";
import {
  ForumChannelLink,
  TagChannelLink,
  TextChannelLink,
  VoiceChannelLink,
  voiceParticipantLinks,
} from "./channel-links.js";
import { channelKey } from "./sidebar-sections.js";

/**
 * Builds the one list of channels the sidebar shows, out of categories, tags
 * and chat channels.
 *
 * It lives for the whole app rather than in the sidebar section, because the
 * sidebar recreates section instances freely and the link objects carry
 * unread counts that need refreshing from one place.
 */
export default class ChannelDirectory {
  @service currentUser;
  @service site;
  @service siteSettings;
  @service topicTrackingState;

  #forumLinks = new Map();
  #tagLinks = new Map();
  #textLinks = new Map();

  // order.
  #withParticipants = (link) =>
    link instanceof VoiceChannelLink
      ? [
          link,
          ...voiceParticipantLinks({
            room: link.room,
            voiceRooms: this.voiceRooms,
            voiceWebrtc: this.voiceWebrtc,
            user: this.currentUser,
          }),
        ]
      : [link];

  constructor(owner, sidebarSections, channelActions) {
    setOwner(this, owner);
    this.sidebarSections = sidebarSections;
    this.channelActions = channelActions;

    this.chat = owner.lookup("service:chat");
    this.chatChannelsManager = owner.lookup("service:chat-channels-manager");
    this.voiceRooms = owner.lookup("service:live-rooms");
    this.voiceWebrtc = owner.lookup("service:live-webrtc");

    this.topicTrackingState.onStateChange(() => this.#refreshCounts());
  }

  /**
   * The channels in no section, for the top of the list, then each section's.
   * A section only lists channels the user can see, in the order it stores
   * them.
   *
   * @returns {{ top: Array, sections: Array<{ name: string, links: Array }> }}
   */
  @cached
  get layout() {
    const links = this.#allLinks;
    const byKey = new Map(links.map((link) => [link.channelKey, link]));
    const placed = new Set();

    const sections = this.sidebarSections.sections.map((section) => ({
      name: section.name,
      links: (section.channels || [])
        .map(({ type, id }) => {
          const key = channelKey(type, id);
          placed.add(key);
          return byKey.get(key);
        })
        .filter(Boolean)
        .flatMap(this.#withParticipants),
    }));

    // Sections keep the order they were arranged in; the rest are one list,
    // whatever their kind, by name.
    return {
      top: links
        .filter((link) => !placed.has(link.channelKey))
        .sort((a, b) =>
          a.sortName.localeCompare(b.sortName, undefined, {
            sensitivity: "base",
          })
        )
        .flatMap(this.#withParticipants),
      sections,
    };
  }

  get #allLinks() {
    const links = this.categories.map((category) => this.#forumLink(category));

    links.push(...this.#textChannels.map((channel) => this.#textLink(channel)));
    links.push(...this.#voiceRooms.map((room) => this.#voiceLink(room)));

    if (settings.include_tags) {
      links.push(...this.#tags.map((tag) => this.#tagLink(tag)));
    }

    return links;
  }

  // Every category the user can see, like every channel in a chat server,
  // so a channel shows up as soon as it's made. The categories that only back
  // chat channels are left out: the chat channel stands in for them.
  @cached
  get categories() {
    const container = Category.findSingleBySlug(
      settings.chat_container_category
    );
    let sorted = [...this.site.categories];

    if (!this.siteSettings.fixed_category_positions) {
      sorted.sort((a, b) => a.name.localeCompare(b.name));
    }

    return Category.sortCategories(sorted).filter(
      (category) =>
        !(container && this.#isWithin(category, container)) &&
        canDisplayCategory(category.id, this.siteSettings)
    );
  }

  get #tags() {
    if (!this.siteSettings.tagging_enabled) {
      return [];
    }

    const tags =
      this.currentUser?.sidebarTags?.length > 0
        ? this.currentUser.sidebarTags
        : this.site.navigation_menu_site_top_tags || [];

    return tags.filter((tag) => !tag.pm_only);
  }

  get #textChannels() {
    if (
      !settings.include_chat_channels ||
      !this.chatChannelsManager ||
      !(this.chat?.userCanChat || this.chat?.anonymousUserCanViewPublicChat)
    ) {
      return [];
    }

    // Joined channels, and every open one the user can see (see
    // OpenChannels), since opening one joins it.
    return this.chatChannelsManager.channels.filter(
      (channel) =>
        channel.isCategoryChannel &&
        (channel.currentUserMembership?.following ||
          channel.isOpen ||
          this.chat.anonymousUserCanViewPublicChat)
    );
  }

  get #voiceRooms() {
    if (!this.voiceRooms || !this.siteSettings.live_enabled) {
      return [];
    }

    return [...this.voiceRooms.rooms].sort((a, b) =>
      a.name.localeCompare(b.name)
    );
  }

  linkNamed(name) {
    const { top, sections } = this.layout;
    return [...top, ...sections.flatMap((section) => section.links)].find(
      (link) => link.name === name
    );
  }

  #isWithin(category, ancestor) {
    for (let c = category; c; c = c.parentCategory) {
      if (c.id === ancestor.id) {
        return true;
      }
    }
    return false;
  }

  #forumLink(category) {
    return this.#memo(this.#forumLinks, category.id, () => {
      return new ForumChannelLink({
        category,
        topicTrackingState: this.topicTrackingState,
        currentUser: this.currentUser,
      });
    });
  }

  #tagLink(tag) {
    return this.#memo(this.#tagLinks, tag.id, () => {
      return new TagChannelLink({
        tag,
        topicTrackingState: this.topicTrackingState,
        currentUser: this.currentUser,
      });
    });
  }

  #textLink(channel) {
    return this.#memo(
      this.#textLinks,
      channel.id,
      () => new TextChannelLink({ channel })
    );
  }

  // Not memoized: the live plugin swaps in a new room object on every update,
  // so a fresh link per render is what keeps it current.
  #voiceLink(room) {
    return this.channelActions.decorate(
      new VoiceChannelLink({ room, voiceWebrtc: this.voiceWebrtc })
    );
  }

  // Who's in a voice channel sits under it, so it's added once the list is in

  #memo(map, key, build) {
    if (!map.has(key)) {
      map.set(key, this.channelActions.decorate(build()));
    }
    return map.get(key);
  }

  #refreshCounts() {
    this.#forumLinks.forEach((link) => link.refreshCounts());
    this.#tagLinks.forEach((link) => link.refreshCounts());
  }
}
