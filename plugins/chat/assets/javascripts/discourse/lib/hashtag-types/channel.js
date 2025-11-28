import { service } from "@ember/service";
import replaceEmoji from "discourse/helpers/replace-emoji";
import HashtagTypeBase from "discourse/lib/hashtag-types/base";
import { iconHTML } from "discourse/lib/icon-library";

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

    if (hashtag.emoji) {
      return String(replaceEmoji(`:${hashtag.emoji}:`));
    } else {
      return iconHTML(hashtag.icon, {
        class: `hashtag-color--${this.type}-${hashtag.id}`,
      });
    }
  }

  isLoaded(id) {
    return super.isLoaded(id);
  }
}
