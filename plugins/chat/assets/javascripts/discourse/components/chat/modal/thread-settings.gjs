import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
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
      @closeModal={{@closeModal}}
      class="chat-modal-thread-settings"
      @inline={{@inline}}
      @title={{i18n "chat.thread_title_modal.title"}}
    >
      <:headerPrimaryAction>
        <DButton
          @disabled={{this.buttonDisabled}}
          @action={{this.saveThread}}
          @label="chat.save"
          class="btn-transparent btn-primary"
        />
      </:headerPrimaryAction>
      <:body>
        <Input
          name="thread-title"
          class="chat-modal-thread-settings__title-input"
          maxlength="100"
          placeholder={{i18n "chat.thread_title_modal.input_placeholder"}}
          @type="text"
          @value={{this.editedTitle}}
        />
        <div class="thread-title-length">
          <span>{{this.threadTitleLength}}</span>/100
        </div>

        {{#if this.currentUser.admin}}
          <div class="discourse-ai-cta">
            <p class="discourse-ai-cta__title">{{icon "circle-info"}}
              {{i18n "chat.thread_title_modal.discourse_ai.title"}}</p>
            <p class="discourse-ai-cta__description">{{htmlSafe
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
          @disabled={{this.buttonDisabled}}
          @action={{this.saveThread}}
          @label="save"
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
