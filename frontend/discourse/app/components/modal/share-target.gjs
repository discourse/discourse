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

  <template>
    <DModal
      @title={{i18n "share_target.title"}}
      @closeModal={{@closeModal}}
      class="share-target-modal"
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
                  class="share-target-modal__thumbnail"
                  src={{preview.url}}
                  alt={{preview.name}}
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
          @action={{this.createTopic}}
          @label="share_target.new_topic"
          @icon="far-pen-to-square"
          class="btn-primary share-target-modal__new-topic"
        />
        <DButton
          @action={{this.createMessage}}
          @label="share_target.new_message"
          @icon="envelope"
          class="share-target-modal__new-message"
        />
        <DButton
          @action={{this.addToReply}}
          @label="share_target.add_to_reply"
          @icon="reply"
          class="share-target-modal__add-to-reply"
        />
      </:footer>
    </DModal>
  </template>
}
