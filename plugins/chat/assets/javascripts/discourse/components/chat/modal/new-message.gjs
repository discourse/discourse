import Component from "@glimmer/component";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import MessageCreator from "discourse/plugins/chat/discourse/components/chat/message-creator";

export default class ChatModalNewMessage extends Component {
  @service chat;
  @service siteSettings;

  get shouldRender() {
    return (
      this.siteSettings.enable_public_channels || this.chat.userCanDirectMessage
    );
  }

  <template>
    {{#if this.shouldRender}}
      <DModal
        @closeModal={{@closeModal}}
        class="chat-modal-new-message --quick-palette"
        @title="chat.new_message_modal.title"
        @inline={{@inline}}
        @hideHeader={{true}}
      >
        <MessageCreator @onClose={{@closeModal}} @channel={{@model}} />
      </DModal>
    {{/if}}
  </template>
}
