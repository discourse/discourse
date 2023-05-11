import { isPresent } from "@ember/utils";
import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class ChatReplyingIndicator extends Component {
  @service currentUser;
  @service presence;

  @tracked presenceChannel = null;

  @action
  async updateSubscription() {
    await this.unsubscribe();
    await this.subscribe();
  }

  @action
  async subscribe() {
    this.presenceChannel = this.presence.getChannel(
      this.args.presenceChannelName
    );
    await this.presenceChannel.subscribe();
  }

  @action
  async unsubscribe() {
    if (this.presenceChannel?.subscribed) {
      await this.presenceChannel.unsubscribe();
    }
  }

  get users() {
    return (
      this.presenceChannel
        ?.get("users")
        ?.filter((u) => u.id !== this.currentUser.id) || []
    );
  }

  get usernames() {
    return this.users.mapBy("username");
  }

  get text() {
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
}
