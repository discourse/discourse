import { bind } from "discourse-common/utils/decorators";

export default {
  name: "user-tips",
  after: "message-bus",

  initialize(container) {
    this.currentUser = container.lookup("service:current-user");
    if (!this.currentUser) {
      return;
    }

    this.messageBus = container.lookup("service:message-bus");
    this.site = container.lookup("service:site");

    this.messageBus.subscribe(
      `/user-tips/${this.currentUser.id}`,
      this.onMessage
    );
  },

  teardown() {
    if (this.currentUser) {
      this.messageBus?.unsubscribe(
        `/user-tips/${this.currentUser.id}`,
        this.onMessage
      );
    }
  },

  @bind
  onMessage(seenUserTips) {
    if (!this.site.user_tips) {
      return;
    }

    this.currentUser.set("seen_popups", seenUserTips);

    if (!this.currentUser.user_option) {
      this.currentUser.set("user_option", {});
    }

    this.currentUser.set("user_option.seen_popups", seenUserTips);

    (seenUserTips || []).forEach((userTipId) => {
      this.currentUser.hideUserTipForever(
        Object.keys(this.site.user_tips).find(
          (id) => this.site.user_tips[id] === userTipId
        )
      );
    });
  },
};
