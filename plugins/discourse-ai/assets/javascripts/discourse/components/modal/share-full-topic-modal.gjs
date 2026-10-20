import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { clipboardCopyAsync, escapeExpression } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class ShareModal extends Component {
  @service dialog;
  @service toasts;

  @tracked confirmationOpen = false;
  @tracked deleting = false;
  @tracked shareKey = "";
  @tracked sharing = false;

  constructor() {
    super(...arguments);
    this.shareKey = this.args.model.share_key;
  }

  get busy() {
    return this.sharing || this.deleting || this.confirmationOpen;
  }

  get htmlContext() {
    let context = [];

    this.args.model.context.forEach((post) => {
      const preview = new DOMParser().parseFromString(post.cooked, "text/html");
      preview
        .querySelectorAll(".ai-artifact-controls, .copy-embed")
        .forEach((control) => control.remove());
      context.push(`<p><b>${escapeExpression(post.username)}:</b></p>`);
      context.push(preview.body.innerHTML);
    });
    return trustHTML(context.join("\n"));
  }

  get primaryLabel() {
    return this.shareKey
      ? "discourse_ai.ai_bot.share_full_topic_modal.update"
      : "discourse_ai.ai_bot.share_full_topic_modal.share";
  }

  async generateShareURL() {
    const response = await ajax(
      "/discourse-ai/ai-bot/shared-ai-conversations",
      {
        type: "POST",
        data: { topic_id: this.args.model.topic_id },
      }
    );
    const url = getAbsoluteURL(
      `/discourse-ai/ai-bot/shared-ai-conversations/${response.share_key}`
    );
    this.shareKey = response.share_key;

    return new Blob([url], { type: "text/plain" });
  }

  @action
  deleteLink() {
    if (this.busy || !this.shareKey) {
      return;
    }
    this.confirmationOpen = true;
    return this.dialog.confirm({
      title: i18n("discourse_ai.ai_artifact.confirm_revoke_conversation_title"),
      message: i18n(
        "discourse_ai.ai_artifact.confirm_revoke_conversation_message"
      ),
      confirmButtonLabel: "discourse_ai.ai_artifact.revoke_conversation",
      confirmButtonClass: "btn-danger",
      didConfirm: () => this.#deleteConfirmed(),
      didCancel: () => {
        this.confirmationOpen = false;
      },
    });
  }

  @action
  async share() {
    if (this.busy) {
      return;
    }
    this.sharing = true;
    try {
      await clipboardCopyAsync(this.generateShareURL.bind(this));
      this.toasts.success({
        duration: "short",
        data: { message: i18n("discourse_ai.ai_bot.conversation_shared") },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.sharing = false;
    }
  }

  async #deleteConfirmed() {
    this.deleting = true;
    try {
      await ajax(
        `/discourse-ai/ai-bot/shared-ai-conversations/${this.shareKey}.json`,
        { type: "DELETE" }
      );
      this.shareKey = null;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.deleting = false;
      this.confirmationOpen = false;
    }
  }

  <template>
    <DModal
      class="ai-share-full-topic-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_ai.ai_bot.share_full_topic_modal.title"}}
    >
      <:body>
        <div class="ai-share-full-topic-modal__body">
          {{this.htmlContext}}
        </div>
      </:body>

      <:footer>
        <DButton
          class="btn-primary confirm"
          @action={{this.share}}
          @disabled={{this.busy}}
          @icon="copy"
          @label={{this.primaryLabel}}
        />
        {{#if this.shareKey}}
          <DButton
            class="btn-danger"
            @action={{this.deleteLink}}
            @disabled={{this.busy}}
            @icon="far-trash-can"
            @label="discourse_ai.ai_bot.share_full_topic_modal.delete"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
