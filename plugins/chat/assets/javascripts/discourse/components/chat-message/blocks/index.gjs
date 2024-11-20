import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Block from "./block";

export default class Blocks extends Component {
  @service appEvents;
  @service chatApi;

  @action
  async createInteraction(id) {
    try {
      const result = await this.chatApi.createInteraction(
        this.args.message.channel.id,
        this.args.message.id,
        { action_id: id }
      );

      this.appEvents.trigger("chat:message_interaction", result.interaction);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    {{#if @message.blocks}}
      <div class="chat-message__blocks-wrapper">
        <div class="chat-message__blocks">
          {{#each @message.blocks as |blockDefinition|}}
            <Block
              @createInteraction={{this.createInteraction}}
              @definition={{blockDefinition}}
            />
          {{/each}}
        </div>
      </div>
    {{/if}}
  </template>
}
