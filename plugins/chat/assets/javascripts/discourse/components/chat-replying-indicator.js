import { isBlank, isPresent } from "@ember/utils";
import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class ChatReplyingIndicator extends Component {
  @service currentUser;
  @service presence;

  @tracked presenceChannel = null;
  @tracked users = [];

  @action
  async subscribe() {
    this.presenceChannel = this.presence.getChannel(this.channelName);
    this.presenceChannel.on("change", this.handlePresenceChange);
    await this.presenceChannel.subscribe();
  }

  @action
  async resubscribe() {
    await this.teardown();
    await this.subscribe();
  }

  @action
  handlePresenceChange(presenceChannel) {
    this.users = presenceChannel.users || [];
  }

  @action
  async handleDraft() {
    if (this.args.channel.isDraft) {
      await this.teardown();
    } else {
      await this.resubscribe();
    }
  }

  @action
  async teardown() {
    if (this.presenceChannel) {
      await this.presenceChannel.unsubscribe();
    }
  }

  get usernames() {
    return this.users
      .filter((u) => u.id !== this.currentUser.id)
      .mapBy("username");
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
      const lastUsername = this.usernames[this.usernames.length - 1];
      const commaSeparatedUsernames = this.usernames
        .slice(0, this.usernames.length - 1)
        .join(I18n.t("word_connector.comma"));
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
    return isPresent(this.usernames);
  }

  get channelName() {
    return `/chat-reply/${this.args.channel.id}`;
  }
}
