import { bind } from "discourse-common/utils/decorators";

export default {
  after: "message-bus",

  initialize(owner) {
    this.currentUser = owner.lookup("service:current-user");
    if (!this.currentUser) {
      return;
    }

    this.messageBus = owner.lookup("service:message-bus");
    this.site = owner.lookup("service:site");

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
