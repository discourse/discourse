import { getOwner, setOwner } from "@ember/application";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse-common/utils/decorators";
import ChatChatable from "discourse/plugins/chat/discourse/models/chat-chatable";

const MAX_RESULTS = 10;

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
      includeCategoryChannels: true,
      includeDirectMessageChannels: true,
      excludedUserIds: null,
    }
  ) {
    this.request?.abort();

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
      this.selectedItem = null;

      this.loadingSlider.transitionEnded();

      return [
        ...results.users,
        ...results.direct_message_channels,
        ...results.category_channels,
      ]
        .map((item) => {
          const chatable = ChatChatable.create(item);
          chatable.tracking = this.#injectTracking(chatable);
          return chatable;
        })
        .slice(0, MAX_RESULTS);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  #injectTracking(chatable) {
    return this.chatChannelsManager.allChannels.find(
      (channel) => channel.id === chatable.model.id
    )?.tracking;
  }
}
