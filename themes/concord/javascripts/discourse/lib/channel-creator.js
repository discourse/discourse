import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import { FULL, REPLY, SEE } from "./constants.js";
import { channelKey } from "./sidebar-sections.js";

// Members fetched per group for a private voice channel. Voice rooms only know
// individual members, and each one is a request.
const VOICE_MEMBER_LIMIT = 200;

/**
 * Creates each kind of channel through the endpoint that backs it, and knows
 * what each kind needs to be private.
 *
 * - Forum: a category, restricted to the groups.
 * - Text: a chat channel. Chat channels take their access from a category, so
 *   each one gets its own backing category, kept under one container category.
 *   Posting in the channel only needs Reply there, so that's all it gives,
 *   and nobody but admins can start topics in it. Its "About" topic is closed
 *   too, so the category is only ever used by the channel.
 * - Voice: a voice room. Rooms have members rather than groups, so the groups'
 *   current members are added.
 */
export default class ChannelCreator {
  @service currentUser;
  @service site;
  @service siteSettings;

  constructor(owner) {
    setOwner(this, owner);

    this.chat = owner.lookup("service:chat");
    this.chatApi = owner.lookup("service:chat-api");
    this.chatChannelsManager = owner.lookup("service:chat-channels-manager");
    this.voiceRooms = owner.lookup("service:live-rooms");
  }

  get canCreateForum() {
    return !!this.currentUser?.can_create_category;
  }

  get canCreateText() {
    return (
      !!this.chatApi &&
      this.currentUser?.staff &&
      this.chat?.userCanChat &&
      this.siteSettings.enable_public_channels &&
      this.canCreateForum
    );
  }

  get canCreateVoice() {
    return (
      !!this.voiceRooms &&
      this.siteSettings.live_enabled &&
      this.voiceRooms.canCreateRoom
    );
  }

  get types() {
    return [
      this.canCreateText && "text",
      this.canCreateVoice && "voice",
      this.canCreateForum && "forum",
    ].filter(Boolean);
  }

  get groups() {
    return this.site.groups.filter((group) => group.id !== 0);
  }

  /**
   * @param {object} data
   * @param {"text"|"voice"|"forum"} data.type
   * @param {string} data.name
   * @param {boolean} data.isPrivate
   * @param {number[]} data.groupIds
   * @returns {Promise<{ key: string, route: string, models: Array, notice?: string }>}
   *   The new channel's key, and where to go once it's made.
   */
  async create({ type, name, isPrivate, groupIds }) {
    const groups = isPrivate ? groupIds : [];

    switch (type) {
      case "forum":
        return this.#createForum(name, groups);
      case "text":
        return this.#createText(name, groups);
      case "voice":
        return this.#createVoice(name, isPrivate, groups);
    }
  }

  /**
   * Adds the groups' current members to a voice room, which only knows
   * individual members. People already in the room are left alone, since
   * adding someone again resets their role, and so are bots (negative ids),
   * which rooms refuse.
   *
   * @returns {Promise<string|undefined>} A notice when only some were added.
   */
  async addGroupMembersToRoom(room, groupIds) {
    const [{ userIds, capped }, { memberships }] = await Promise.all([
      this.#groupMemberIds(groupIds),
      ajax(`/live/rooms/${room.id}/memberships`),
    ]);
    const inRoom = new Set(memberships.map((m) => m.user_id));

    for (const userId of userIds) {
      if (userId > 0 && !inRoom.has(userId)) {
        await ajax(`/live/rooms/${room.id}/memberships`, {
          type: "POST",
          data: { user_id: userId },
        });
      }
    }

    if (capped) {
      return i18n(themePrefix("create_channel.voice_members_capped"), {
        count: VOICE_MEMBER_LIMIT,
      });
    }
  }

  async #createForum(name, groupIds) {
    const category = await this.#createCategory({
      name,
      permissions: this.#permissions(groupIds, FULL),
    });

    return {
      key: channelKey("forum", category.id),
      route: "discovery.category",
      models: [`${Category.slugFor(category)}/${category.id}`],
    };
  }

  async #createText(name, groupIds) {
    const container = await this.#chatContainer();
    const category = await this.#createCategory({
      name,
      parent_category_id: container.id,
      permissions: this.#permissions(groupIds, REPLY) || { everyone: REPLY },
    });
    await this.#closeAboutTopic(category);

    // Auto-join puts the channel in everyone's list who can see it, so
    // every member sees every channel they have access to.
    const channel = await this.chatApi.createChannel({
      name,
      chatable_id: category.id,
      auto_join_users: true,
    });
    this.chatChannelsManager.follow(channel);

    return {
      key: channelKey("text", channel.id),
      route: "chat.channel",
      models: channel.routeModels,
    };
  }

  async #createVoice(name, isPrivate, groupIds) {
    const { room } = await ajax("/live/rooms", {
      type: "POST",
      data: { room: { name, public: !isPrivate } },
    });

    const notice = isPrivate
      ? await this.addGroupMembersToRoom(room, groupIds)
      : undefined;

    this.voiceRooms.handleDirectoryEvent({ type: "created", room });

    return {
      key: channelKey("voice", room.id),
      route: "live-room",
      models: [room.slug],
      notice,
    };
  }

  async #createCategory(attributes) {
    const color = this.#randomColor();
    const result = await ajax("/categories", {
      type: "POST",
      data: { color, text_color: "FFFFFF", ...attributes },
    });

    return this.site.updateCategory(result.category);
  }

  // Found by slug so the theme needn't store anything. It stays open to
  // everyone: a parent restricted to some groups would refuse children for
  // any other group.
  async #chatContainer() {
    const slug = settings.chat_container_category;
    const existing = Category.findSingleBySlug(slug);

    if (existing) {
      return existing;
    }

    return this.#createCategory({
      name: i18n(themePrefix("create_channel.container_name")),
      slug,
      permissions: { everyone: SEE },
    });
  }

  // The topic core starts every category with, taking replies like any other.
  async #closeAboutTopic(category) {
    const topicId = category.topic_url?.match(/\/(\d+)\/?$/)?.[1];
    if (topicId) {
      await ajax(`/t/${topicId}/status`, {
        type: "PUT",
        data: { status: "closed", enabled: true },
      });
    }
  }

  // Category permissions are keyed by group name.
  #permissions(groupIds, level) {
    if (!groupIds.length) {
      return undefined;
    }

    const permissions = {};

    for (const group of this.site.groups) {
      if (groupIds.includes(group.id)) {
        permissions[group.name] = level;
      }
    }

    return permissions;
  }

  async #groupMemberIds(groupIds) {
    const userIds = new Set();
    let capped = false;

    for (const group of this.site.groups) {
      if (!groupIds.includes(group.id)) {
        continue;
      }

      const { members, meta } = await ajax(
        `/groups/${group.name}/members.json`,
        { data: { limit: VOICE_MEMBER_LIMIT } }
      );

      members.forEach((member) => userIds.add(member.id));
      capped ||= meta.total > members.length;
    }

    if (userIds.size > VOICE_MEMBER_LIMIT) {
      capped = true;
    }

    return {
      userIds: [...userIds].slice(0, VOICE_MEMBER_LIMIT),
      capped,
    };
  }

  #randomColor() {
    const colors = this.siteSettings.category_colors?.split("|") || [];
    return colors[Math.floor(Math.random() * colors.length)] || "0088CC";
  }
}
