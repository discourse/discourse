import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ChatModalThreadSettings extends Component {
  @service chatApi;
  @service currentUser;

  @tracked editedTitle = this.thread.title || "";
  @tracked saving = false;

  get buttonDisabled() {
    return this.saving;
  }

  get thread() {
    return this.args.model;
  }

  get threadTitleLength() {
    return this.editedTitle.length;
  }

  @action
  saveThread() {
    this.saving = true;

    this.chatApi
      .editThread(this.thread.channel.id, this.thread.id, {
        title: this.editedTitle,
      })
      .then(() => {
        this.thread.title = this.editedTitle;
        this.args.closeModal();
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.saving = false;
      });
  }

  <template>
    <DModal
      class="chat-modal-thread-settings"
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @title={{i18n "chat.thread_title_modal.title"}}
    >
      <:headerPrimaryAction>
        <DButton
          class="btn-transparent --primary"
          @action={{this.saveThread}}
          @disabled={{this.buttonDisabled}}
          @label="chat.save"
        />
      </:headerPrimaryAction>
      <:body>
        <Input
          class="chat-modal-thread-settings__title-input"
          maxlength="100"
          name="thread-title"
          placeholder={{i18n "chat.thread_title_modal.input_placeholder"}}
          @type="text"
          @value={{this.editedTitle}}
        />
        <div class="thread-title-length">
          <span>{{this.threadTitleLength}}</span>/100
        </div>

        {{#if this.currentUser.admin}}
          <div class="discourse-ai-cta">
            <p class="discourse-ai-cta__title">{{dIcon "circle-info"}}
              {{i18n "chat.thread_title_modal.discourse_ai.title"}}</p>
            <p class="discourse-ai-cta__description">{{trustHTML
                (i18n
                  "chat.thread_title_modal.discourse_ai.description"
                  url="<a href='https://www.discourse.org/ai' rel='noopener noreferrer' target='_blank'>Discourse AI</a>"
                )
              }}
            </p>
          </div>
        {{/if}}
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.saveThread}}
          @disabled={{this.buttonDisabled}}
          @label="save"
        />
      </:footer>
    </DModal>
  </template>
}
