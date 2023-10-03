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
      `.d-icon.hashtag-color--${this.type}-${channel.id} { color: var(--category-${channel.chatable.id}-color); }`,
    ];
  }

  generateIconHTML(hashtag) {
    const hashtagId = parseInt(hashtag.id, 10);
    const colorCssClass = !this.preloadedData.mapBy("id").includes(hashtagId)
      ? "hashtag-missing"
      : `hashtag-color--${this.type}-${hashtag.id}`;
    return iconHTML(hashtag.icon, {
      class: colorCssClass,
    });
  }
}
