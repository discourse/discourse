import HashtagTypeBase from "discourse/lib/hashtag-types/base";
import { iconHTML } from "discourse-common/lib/icon-library";
import { inject as service } from "@ember/service";

export default class ChannelHashtagType extends HashtagTypeBase {
  @service chatChannelsManager;
  @service currentUser;

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

  generateColorCssClasses(channel) {
    return [
      `.hashtag-cooked .d-icon.hashtag-color--${this.type}-${channel.id} { color: var(--category-${channel.chatable.id}-color); }`,
    ];
  }

  generateIconHTML(hashtag) {
    return iconHTML(hashtag.icon, {
      class: `hashtag-color--${this.type}-${hashtag.id}`,
    });
  }
}
