import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

let createChannelForm;

export default class ChatModalCreateChannel extends Component {
  @tracked flash;
  @tracked formApi;

  get createChannelForm() {
    return (createChannelForm ??= import("../create-channel-form.gjs"));
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  setFlash(flash) {
    this.flash = flash;
  }

  @action
  submit() {
    this.formApi.submit();
  }

  <template>
    <DModal
      class="chat-modal-create-channel"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @inline={{@inline}}
      @title={{i18n "chat.create_channel.title"}}
    >
      <:body>
        <DAsyncContent @asyncData={{this.createChannelForm}}>
          <:loading>
            <DConditionalLoadingSpinner @condition={{true}} />
          </:loading>
          <:content as |module|>
            <module.default
              @closeModal={{@closeModal}}
              @onError={{this.setFlash}}
              @onRegisterApi={{this.registerApi}}
            />
          </:content>
        </DAsyncContent>
      </:body>
      <:footer>
        <DButton
          class="btn-primary create"
          @action={{this.submit}}
          @disabled={{not this.formApi}}
          @label="chat.create_channel.create"
        />
      </:footer>
    </DModal>
  </template>
}
