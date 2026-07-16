import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";

export default class AiPostImageCaptionEditorModal extends Component {
  @service postImageCaptionEditor;

  @cached
  get formData() {
    return {
      description: this.args.model.description,
    };
  }

  @action
  async save(data) {
    try {
      await this.postImageCaptionEditor.save(
        this.args.model.base62Sha1,
        data.description
      );
      this.args.closeModal();
    } catch {
      // popupAjaxError is handled by the service.
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_ai.post_image_captions.title"}}
      class="ai-post-image-caption-editor-modal"
    >
      <Form @data={{this.formData}} @onSubmit={{this.save}} as |form|>
        <form.Field
          @format="full"
          @name="description"
          @title={{i18n "discourse_ai.post_image_captions.description"}}
          @type="textarea"
          @validation="required:trim|length:1,1000"
          as |field|
        >
          <field.Control
            @height={{120}}
            class="ai-post-image-caption-editor-modal__textarea"
          />
        </form.Field>

        <form.Actions>
          <DModalCancel @close={{@closeModal}} />
          <form.Submit @label="discourse_ai.post_image_captions.save" />
        </form.Actions>
      </Form>
    </DModal>
  </template>
}
