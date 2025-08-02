import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

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
      return i18n("chat.replying_indicator.single_user", {
        username: this.usernames[0],
      });
    }

    if (this.usernames.length < 4) {
      const lastUsername = this.usernames[this.usernames.length - 1];
      const commaSeparatedUsernames = this.usernames
        .slice(0, this.usernames.length - 1)
        .join(i18n("word_connector.comma"));
      return i18n("chat.replying_indicator.multiple_users", {
        commaSeparatedUsernames,
        lastUsername,
      });
    }

    const commaSeparatedUsernames = this.usernames
      .slice(0, 2)
      .join(i18n("word_connector.comma"));
    return i18n("chat.replying_indicator.many_users", {
      commaSeparatedUsernames,
      count: this.usernames.length - 2,
    });
  }

  get shouldRender() {
    return isPresent(this.usernames);
  }

  <template>
    {{#if @presenceChannelName}}
      <div
        class={{concatClass
          "chat-replying-indicator"
          (if this.presenceChannel.subscribed "is-subscribed")
        }}
        {{didInsert this.subscribe}}
        {{didUpdate this.updateSubscription @presenceChannelName}}
        {{willDestroy this.unsubscribe}}
      >
        {{#if this.shouldRender}}
          <span class="chat-replying-indicator__text">{{this.text}}</span>
          <span class="chat-replying-indicator__wave">
            <span class="chat-replying-indicator__dot">.</span>
            <span class="chat-replying-indicator__dot">.</span>
            <span class="chat-replying-indicator__dot">.</span>
          </span>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
