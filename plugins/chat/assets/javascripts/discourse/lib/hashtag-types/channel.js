import { service } from "@ember/service";
import HashtagTypeBase from "discourse/lib/hashtag-types/base";
import { iconHTML } from "discourse/lib/icon-library";

export default class ChannelHashtagType extends HashtagTypeBase {
  @service chatChannelsManager;
  @service currentUser;
  @service site;

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
    hashtag.colors ? this.onLoad(hashtag) : this.load(hashtag.id);

    return iconHTML(hashtag.icon, {
      class: `hashtag-color--${this.type}-${hashtag.id}`,
    });
  }

  isLoaded(id) {
    return !this.site.lazy_load_categories || super.isLoaded(id);
  }
}
