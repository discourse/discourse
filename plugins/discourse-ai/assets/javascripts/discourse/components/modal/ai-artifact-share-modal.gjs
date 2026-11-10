import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import { formatAiArtifactPostEmbed } from "discourse/plugins/discourse-ai/discourse/lib/ai-artifact-embed";

export default class AiArtifactShareModal extends Component {
  @service dialog;
  @service siteSettings;
  @service toasts;

  @tracked busy = false;
  @tracked confirmationOpen = false;
  @tracked share = null;

  constructor() {
    super(...arguments);
    this.share = this.args.model.share;
  }

  get blocked() {
    return this.busy || this.confirmationOpen;
  }

  get viewedVersion() {
    return this.args.model.artifactVersion == null
      ? 0
      : Number(this.args.model.artifactVersion);
  }

  get endpoint() {
    return `/discourse-ai/ai-bot/artifact-shares/${this.args.model.artifactId}`;
  }

  @action
  async create() {
    if (this.blocked) {
      return;
    }
    this.busy = true;
    try {
      this.share = await ajax(`${this.endpoint}.json`, {
        type: "POST",
        data: { version: this.viewedVersion },
      });
      this.args.model.onShareChange(this.share);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  @action
  async update() {
    if (this.blocked) {
      return;
    }
    this.busy = true;
    try {
      this.share = await ajax(
        `/discourse-ai/ai-bot/artifact-shares/${this.share.share_key}.json`,
        {
          type: "PUT",
          data: { version: this.viewedVersion },
        }
      );
      this.args.model.onShareChange(this.share);
      this.toasts.success({
        duration: "short",
        data: { message: i18n("discourse_ai.ai_artifact.pin_updated") },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  @action
  revoke() {
    if (this.blocked || !this.share) {
      return;
    }
    this.confirmationOpen = true;
    return this.dialog.confirm({
      title: i18n("discourse_ai.ai_artifact.confirm_revoke_standalone_title"),
      message: i18n(
        "discourse_ai.ai_artifact.confirm_revoke_standalone_message"
      ),
      confirmButtonLabel: "discourse_ai.ai_artifact.revoke",
      confirmButtonClass: "btn-danger",
      didConfirm: () => this.#revokeConfirmed(),
      didCancel: () => {
        this.confirmationOpen = false;
      },
    });
  }

  @action
  async copyLink() {
    if (this.blocked || !this.share) {
      return;
    }
    try {
      await clipboardCopy(this.share.url);
      this.toasts.success({
        duration: "short",
        data: { message: i18n("discourse_ai.ai_artifact.copied") },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async copyPostEmbed() {
    if (this.blocked || !this.share) {
      return;
    }
    try {
      await clipboardCopy(formatAiArtifactPostEmbed(this.share));
      this.toasts.success({
        duration: "short",
        data: { message: i18n("discourse_ai.ai_artifact.copied") },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async copyWebsiteEmbed() {
    if (this.blocked || !this.share) {
      return;
    }
    try {
      await clipboardCopy(
        `<iframe src="${this.share.url}" width="100%" height="600" frameborder="0"></iframe>`
      );
      this.toasts.success({
        duration: "short",
        data: { message: i18n("discourse_ai.ai_artifact.copied") },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async #revokeConfirmed() {
    this.busy = true;
    try {
      await ajax(
        `/discourse-ai/ai-bot/artifact-shares/${this.share.share_key}.json`,
        { type: "DELETE" }
      );
      this.share = null;
      this.args.model.onShareChange(null);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
      this.confirmationOpen = false;
    }
  }

  <template>
    <DModal
      class="ai-artifact-share-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_ai.ai_artifact.share"}}
    >
      <:body>
        <p>{{i18n
            (if
              this.siteSettings.login_required
              "discourse_ai.ai_artifact.privacy_notice_login_required"
              "discourse_ai.ai_artifact.privacy_notice"
            )
          }}</p>
        {{#if this.share}}
          <p>
            <a
              class="ai-artifact-share-modal__link"
              href={{this.share.url}}
              rel="noopener noreferrer"
              target="_blank"
            >{{this.share.url}}</a>
          </p>
          <div class="ai-artifact-share-modal__actions">
            <DButton
              class="ai-artifact-share-modal__copy-link"
              @action={{this.copyLink}}
              @disabled={{this.blocked}}
              @icon="link"
              @label="discourse_ai.ai_artifact.copy_link"
            />
            <DButton
              class="ai-artifact-share-modal__embed-post"
              @action={{this.copyPostEmbed}}
              @disabled={{this.blocked}}
              @icon="code"
              @label="discourse_ai.ai_artifact.embed_post"
              @title="discourse_ai.ai_artifact.embed_post_title"
            />
            <DButton
              class="ai-artifact-share-modal__embed-website"
              @action={{this.copyWebsiteEmbed}}
              @disabled={{this.blocked}}
              @icon="code"
              @label="discourse_ai.ai_artifact.embed_website"
              @title="discourse_ai.ai_artifact.embed_website_title"
            />
            <DButton
              rel="noopener noreferrer"
              target="_blank"
              @href={{this.share.url}}
              @label="discourse_ai.ai_artifact.new_tab"
            />
            <DButton
              class="ai-artifact-share-modal__update"
              @action={{this.update}}
              @disabled={{this.blocked}}
              @icon="arrows-rotate"
              @label="discourse_ai.ai_artifact.update_pin"
            />
            <DButton
              class="btn-danger ai-artifact-share-modal__revoke"
              @action={{this.revoke}}
              @disabled={{this.blocked}}
              @icon="far-trash-can"
              @label="discourse_ai.ai_artifact.revoke"
            />
          </div>
        {{else}}
          <DButton
            class="btn-primary ai-artifact-share-modal__create"
            @action={{this.create}}
            @disabled={{this.busy}}
            @isLoading={{this.busy}}
            @label="discourse_ai.ai_artifact.create_link"
          />
        {{/if}}
      </:body>
    </DModal>
  </template>
}
