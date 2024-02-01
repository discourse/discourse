import { inject as service } from "@ember/service";
import HashtagTypeBase from "discourse/lib/hashtag-types/base";
import { iconHTML } from "discourse-common/lib/icon-library";

export default class ChannelHashtagType extends HashtagTypeBase {
  @service chatChannelsManager;
  @service currentUser;

  constructor() {
    super(...arguments);
    this.loadingIds = new Set();
  }

  get type() {
    return "channel";
  }

  get preloadedData() {
    if (this.currentUser) {
      return this.chatChannelsManager.publicMessageChannels;
    } else {
      return [];
    }
  }

  generateColorCssClasses(channelOrHashtag) {
    const color = channelOrHashtag.colors
      ? channelOrHashtag.colors[0]
      : channelOrHashtag.chatable.color;

    return [
      `.d-icon.hashtag-color--${this.type}-${channelOrHashtag.id} { color: #${color} }`,
    ];
  }

  generateIconHTML(hashtag) {
    if (!this.registeredIds.has(parseInt(hashtag.id, 10))) {
      if (hashtag.colors) {
        this.registerCss(hashtag);
      } else {
        this.load(hashtag.id);
      }
    }

    return iconHTML(hashtag.icon, {
      class: `hashtag-color--${this.type}-${hashtag.id}`,
    });
  }
}
