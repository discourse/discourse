import { isBlank, isPresent } from "@ember/utils";
import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { next } from "@ember/runloop";
import { tracked } from "@glimmer/tracking";
import I18n from "I18n";
import { action } from "@ember/object";

export default class ChatReplyingIndicator extends Component {
  @service presence;
  @service currentUser;

  @tracked presenceChannel;

  @action
  setupPresence() {
    if (!this.args.channel || this.args.channel.isDraft) {
      this.presenceChannel?.unsubscribe();
      return;
    }

    if (this.presenceChannel?.name !== this.channelName) {
      this.presenceChannel?.unsubscribe();

      next(() => {
        if (this.isDestroyed || this.isDestroying) {
          return;
        }

        const presenceChannel = this.presence.getChannel(this.channelName);
        presenceChannel.__yoo = 1;
        this.presenceChannel = presenceChannel;
        presenceChannel.subscribe();
      });
    }
  }

  @action
  teardownPresence() {
    this.presenceChannel?.unsubscribe();
  }

  get presenceChannelUsers() {
    return this.presenceChannel?.get("users") || [];
  }

  get usernames() {
    return this.presenceChannelUsers
      ?.filter((u) => u.id !== this.currentUser.id)
      ?.map((user) => user.username);
  }

  get text() {
    if (isBlank(this.usernames)) {
      return;
    }

    if (this.usernames.length === 1) {
      return I18n.t("chat.replying_indicator.single_user", {
        username: this.usernames[0],
      });
    }

    if (this.usernames.length < 4) {
      const lastUsername = this.usernames.pop();
      const commaSeparatedUsernames = this.usernames.join(
        I18n.t("word_connector.comma")
      );
      return I18n.t("chat.replying_indicator.multiple_users", {
        commaSeparatedUsernames,
        lastUsername,
      });
    }

    const commaSeparatedUsernames = this.usernames
      .slice(0, 2)
      .join(I18n.t("word_connector.comma"));
    return I18n.t("chat.replying_indicator.many_users", {
      commaSeparatedUsernames,
      count: this.usernames.length - 2,
    });
  }

  get shouldRender() {
    console.log(this.usernames);
    return isPresent(this.usernames);
  }

  get channelName() {
    return `/chat-reply/${this.args.channel.id}`;
  }
}
