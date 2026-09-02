import Component from "@glimmer/component";
import { service } from "@ember/service";
import DModal from "discourse/ui-kit/d-modal";
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
        class="chat-modal-new-message --quick-palette"
        @closeModal={{@closeModal}}
        @hideHeader={{true}}
        @inline={{@inline}}
        @title="chat.new_message_modal.title"
      >
        <MessageCreator @channel={{@model}} @onClose={{@closeModal}} />
      </DModal>
    {{/if}}
  </template>
}
