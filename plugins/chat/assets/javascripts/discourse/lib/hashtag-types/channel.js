import HashtagTypeBase from "discourse/lib/hashtag-types/base";
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

  generateColorCssClasses(model) {
    return [
      `.hashtag-cooked .d-icon.hashtag-color--${this.type}-${model.id} { color: var(--category-${model.chatable.id}-color); }`,
    ];
  }
}
