import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class ChatUserCardButton extends Component {
  @service chat;
  @service appEvents;
  @service router;

  get shouldRender() {
    return this.chat.userCanDirectMessage && !this.args.user.suspended;
  }

  @action
  startChatting() {
    return this.chat
      .upsertDmChannelForUsernames([this.args.user.username])
      .then((channel) => {
        this.router.transitionTo("chat.channel", ...channel.routeModels);
        this.appEvents.trigger("card:close");
      });
  }

  <template>
    {{#if this.shouldRender}}
      <DButton
        @action={{this.startChatting}}
        @label="chat.title_capitalized"
        @icon="d-chat"
        class="btn-primary chat-user-card-btn"
      />
    {{/if}}
  </template>
}
