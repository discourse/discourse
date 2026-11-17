import Component from "@glimmer/component";
import { service } from "@ember/service";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";

let messageCreator;

export default class ChatModalNewMessage extends Component {
  @service chat;
  @service siteSettings;

  get shouldRender() {
    return (
      this.siteSettings.enable_public_channels || this.chat.userCanDirectMessage
    );
  }

  get messageCreator() {
    return (messageCreator ??= import("../message-creator/index.gjs"));
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
        <DAsyncContent @asyncData={{this.messageCreator}}>
          <:loading>
            <DConditionalLoadingSpinner @condition={{true}} />
          </:loading>
          <:content as |module|>
            <module.default
              @channel={{@model}}
              @initialMode={{@model.initialMode}}
              @onClose={{@closeModal}}
            />
          </:content>
        </DAsyncContent>
      </DModal>
    {{/if}}
  </template>
}
