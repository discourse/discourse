import HashtagTypeBase from "discourse/lib/hashtag-types/base";

export default class ChannelHashtagType extends HashtagTypeBase {
  get type() {
    return "channel";
  }

  get preloadedData() {
    const currentUser = this.container.lookup("service:current-user");
    if (currentUser) {
      return this.container.lookup("service:chat-channels-manager")
        .publicMessageChannels;
    } else {
      return [];
    }
  }

  generateColorCssClasses(model) {
    return [
      `.hashtag-color--${this.type}-${model.id} {
      color: var(--category-${model.chatable.id}-color);
      }`,
    ];
  }
}
