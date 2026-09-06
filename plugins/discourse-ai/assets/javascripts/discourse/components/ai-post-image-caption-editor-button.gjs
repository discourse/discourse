import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import AiPostImageCaptionEditorModal from "./modal/ai-post-image-caption-editor";

export default class AiPostImageCaptionEditorButton extends Component {
  @service modal;
  @service postImageCaptionEditor;

  get caption() {
    return this.postImageCaptionEditor.captionFor(this.args.base62Sha1);
  }

  @action
  openEditor() {
    this.modal.show(AiPostImageCaptionEditorModal, {
      model: {
        base62Sha1: this.args.base62Sha1,
        description: this.caption,
      },
    });
  }

  <template>
    {{#if this.caption}}
      <DButton
        @action={{this.openEditor}}
        @ariaLabel="discourse_ai.post_image_captions.edit"
        @icon="pencil"
        @title="discourse_ai.post_image_captions.edit"
        class="btn-transparent ai-post-image-caption-editor__button"
      />
    {{/if}}
  </template>
}
