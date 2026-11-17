import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { sharedBody } from "discourse/lib/share-target";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class ShareTargetModal extends Component {
  @service appEvents;
  @service composer;
  @service("shared-content") sharedContent;
  @service toasts;

  previews;

  constructor() {
    super(...arguments);

    // Build image thumbnails for any shared files. Done in the constructor
    // (not a field initializer) so `this.args` is reliably available.
    this.previews = this.files.map((file) => {
      const isImage = file.type?.startsWith("image/");
      return {
        name: file.name,
        isImage,
        url: isImage ? URL.createObjectURL(file) : null,
      };
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.previews.forEach((preview) => {
      if (preview.url) {
        URL.revokeObjectURL(preview.url);
      }
    });
  }

  get title() {
    return this.args.model.title;
  }

  get files() {
    return this.args.model.files || [];
  }

  get body() {
    return sharedBody(this.args.model);
  }

  get hasText() {
    return !!this.body;
  }

  @action
  createTopic() {
    this.#addFilesWhenReady(this.files);
    this.composer.openNewTopic({ title: this.title, body: this.body });
    this.args.closeModal();
  }

  @action
  createMessage() {
    this.#addFilesWhenReady(this.files);
    this.composer.openNewMessage({ title: this.title, body: this.body });
    this.args.closeModal();
  }

  @action
  addToReply() {
    this.sharedContent.storeForReply({ body: this.body, files: this.files });
    this.toasts.success({
      data: { message: i18n("share_target.added_to_reply") },
    });
    this.args.closeModal();
  }

  #addFilesWhenReady(files) {
    if (!files.length) {
      return;
    }

    // Capture `files` in the closure rather than reading from `this` — the
    // modal is torn down by closeModal() before the composer's uploader is
    // ready and fires this event.
    this.appEvents.one("composer:uploader-ready", () => {
      this.appEvents.trigger("composer:add-files", files);
    });
  }

  <template>
    <DModal
      class="share-target-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "share_target.title"}}
    >
      <:body>
        <p class="share-target-modal__intro">{{i18n
            "share_target.description"
          }}</p>

        {{#if this.hasText}}
          <div class="share-target-modal__preview-text">{{this.body}}</div>
        {{/if}}

        {{#if this.previews.length}}
          <div class="share-target-modal__files">
            {{#each this.previews as |preview|}}
              {{#if preview.isImage}}
                <img
                  alt={{preview.name}}
                  class="share-target-modal__thumbnail"
                  src={{preview.url}}
                />
              {{else}}
                <span
                  class="share-target-modal__file-name"
                >{{preview.name}}</span>
              {{/if}}
            {{/each}}
          </div>
        {{/if}}
      </:body>

      <:footer>
        <DButton
          class="btn-primary share-target-modal__new-topic"
          @action={{this.createTopic}}
          @icon="far-pen-to-square"
          @label="share_target.new_topic"
        />
        <DButton
          class="share-target-modal__new-message"
          @action={{this.createMessage}}
          @icon="envelope"
          @label="share_target.new_message"
        />
        <DButton
          class="share-target-modal__add-to-reply"
          @action={{this.addToReply}}
          @icon="reply"
          @label="share_target.add_to_reply"
        />
      </:footer>
    </DModal>
  </template>
}
