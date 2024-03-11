import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class ChatUserCardButton extends Component {
  @service chat;
  @service appEvents;
  @service router;

  get shouldRender() {
    return this.chat.userCanDirectMessage && !this.args.user.suspended;
  }

  @action
  async startChatting() {
    try {
      const channel = await this.chat.upsertDmChannel({
        usernames: [this.args.user.username],
      });

      if (channel) {
        this.router.transitionTo("chat.channel", ...channel.routeModels);
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.appEvents.trigger("card:close");
    }
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
