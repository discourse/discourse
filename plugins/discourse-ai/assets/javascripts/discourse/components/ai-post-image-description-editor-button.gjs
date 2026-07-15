import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import AiPostImageDescriptionEditorModal from "./modal/ai-post-image-description-editor";

export default class AiPostImageDescriptionEditorButton extends Component {
  @service modal;
  @service postImageDescriptionEditor;

  get description() {
    return this.postImageDescriptionEditor.descriptionFor(this.args.base62Sha1);
  }

  @action
  openEditor() {
    this.modal.show(AiPostImageDescriptionEditorModal, {
      model: {
        base62Sha1: this.args.base62Sha1,
        description: this.description,
      },
    });
  }

  <template>
    {{#if this.description}}
      <DButton
        @action={{this.openEditor}}
        @ariaLabel="discourse_ai.post_image_descriptions.edit"
        @icon="pencil"
        @title="discourse_ai.post_image_descriptions.edit"
        class="btn-transparent ai-post-image-description-editor__button"
      />
    {{/if}}
  </template>
}
