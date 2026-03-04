import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { MATCH_QUALITY_PARTIAL } from "discourse/plugins/chat/discourse/lib/chat-constants";
import ChatChatable from "discourse/plugins/chat/discourse/models/chat-chatable";

const MAX_RESULTS = 10;

const TYPE_PRIORITY = {
  USER: 0,
  DM_CHANNEL: 1,
  CATEGORY_CHANNEL: 2,
  GROUP: 3,
};

function typePriority(chatable) {
  if (chatable.type === "user") {
    return TYPE_PRIORITY.USER;
  }
  if (chatable.type === "group") {
    return TYPE_PRIORITY.GROUP;
  }
  if (chatable.model?.chatableType === "DirectMessage") {
    return TYPE_PRIORITY.DM_CHANNEL;
  }
  return TYPE_PRIORITY.CATEGORY_CHANNEL;
}

export function sortChatables(chatables) {
  return chatables.sort((a, b) => {
    // Primary: match quality (from server, lower is better)
    const matchA = a.matchQuality ?? MATCH_QUALITY_PARTIAL;
    const matchB = b.matchQuality ?? MATCH_QUALITY_PARTIAL;
    if (matchA !== matchB) {
      return matchA - matchB;
    }

    // Secondary: type priority (users > DM channels > category channels > groups)
    const typeA = typePriority(a);
    const typeB = typePriority(b);
    if (typeA !== typeB) {
      return typeA - typeB;
    }

    // Tertiary: enabled before disabled (applies to users and groups)
    if (a.enabled !== b.enabled) {
      return a.enabled ? -1 : 1;
    }

    return 0;
  });
}

export default class ChatablesLoader {
  @service chatChannelsManager;
  @service loadingSlider;

  constructor(context) {
    setOwner(this, getOwner(context));
  }

  @bind
  async search(
    term,
    options = {
      includeUsers: true,
      includeGroups: true,
      includeCategoryChannels: true,
      includeDirectMessageChannels: true,
      preloadChannels: false,
    }
  ) {
    this.request?.abort();

    if (!term && options.preloadChannels) {
      return this.#preloadedChannels();
    }

    if (!term) {
      return [];
    }

    try {
      this.loadingSlider.transitionStarted();
      this.request = ajax("/chat/api/chatables", {
        data: {
          term,
          include_users: options.includeUsers,
          include_category_channels: options.includeCategoryChannels,
          include_direct_message_channels: options.includeDirectMessageChannels,
          excluded_memberships_channel_id: options.excludedMembershipsChannelId,
        },
      });
      const results = await this.request;
      this.loadingSlider.transitionEnded();

      const chatables = [
        ...results.users,
        ...results.groups,
        ...results.direct_message_channels,
        ...results.category_channels,
      ].map((item) => {
        const chatable = ChatChatable.create(item);
        const channel = this.#findChannel(chatable);

        if (channel) {
          chatable.tracking = channel.tracking;
          chatable.unread_thread_count =
            channel.unreadThreadsCountSinceLastViewed;
        }

        return chatable;
      });

      return sortChatables(chatables).slice(0, MAX_RESULTS);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  #preloadedChannels() {
    return this.chatChannelsManager.allChannels
      .map((channel) => {
        let chatable;
        if (channel.chatable?.users?.length === 1) {
          chatable = ChatChatable.createUser(channel.chatable.users[0]);
        } else {
          chatable = ChatChatable.createChannel(channel);
        }

        chatable.tracking = channel.tracking;
        chatable.unread_thread_count =
          channel.unreadThreadsCountSinceLastViewed;
        return chatable;
      })
      .filter(Boolean)
      .slice(0, MAX_RESULTS);
  }

  #findChannel(chatable) {
    if (!["user", "channel"].includes(chatable.type)) {
      return;
    }

    const { allChannels } = this.chatChannelsManager;
    if (chatable.type === "user") {
      return allChannels.find(
        ({ chatable: { users } }) =>
          users?.length === 1 && users[0].id === chatable.model.id
      );
    } else if (chatable.type === "channel") {
      return allChannels.find(({ id }) => id === chatable.model.id);
    }
  }
}
