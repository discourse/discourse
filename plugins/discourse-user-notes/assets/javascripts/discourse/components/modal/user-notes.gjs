import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";
import UserNote from "../user-note";

export default class UserNotesModal extends Component {
  @service dialog;
  @service store;

  @tracked userId = this.args.model.userId;
  postId = this.args.model.postId;
  callback = this.args.model.callback;

  #refreshCount() {
    if (this.callback) {
      this.callback(this.args.model.note.length);
    }
  }

  get subtitle() {
    return applyValueTransformer("user-notes-modal-subtitle", "", {
      model: this.args.model,
    });
  }

  /**
   * Registers the Form API reference.
   *
   * @param {Object} api - The Form API object, with form helper methods.
   */
  @action
  registerApi(api) {
    this.formApi = api;
  }

  /**
   * Handles form submission from Form component.
   *
   * @param {Object} data - Form data from Form component
   */
  @action
  async onSubmit(data) {
    const note = this.store.createRecord("user-note");
    const userId = parseInt(this.userId, 10);

    const args = {
      raw: data.content,
      user_id: userId,
    };

    if (this.postId) {
      args.post_id = parseInt(this.postId, 10);
    }

    try {
      await note.save(args);
      await this.formApi.set("content", "");
      this.args.model.note.insertAt(0, note);
      this.#refreshCount();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  removeNote(note) {
    this.dialog.deleteConfirm({
      message: i18n("user_notes.delete_confirm"),
      didConfirm: () => {
        note
          .destroyRecord()
          .then(() => {
            this.args.model.note.removeObject(note);
            this.#refreshCount();
          })
          .catch(popupAjaxError);
      },
    });
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "user_notes.title"}}
      @subtitle={{this.subtitle}}
      class="user-notes-modal"
    >
      <Form
        @onSubmit={{this.onSubmit}}
        @onRegisterApi={{this.registerApi}}
        as |form|
      >
        <form.Field
          @name="content"
          @title={{i18n "user_notes.attach_note_description"}}
          @format="full"
          @validation="required:trim"
          as |field|
        >
          <field.Textarea />
        </form.Field>

        <form.Actions>
          <form.Submit @label="user_notes.attach" class="btn-primary" />
        </form.Actions>
      </Form>

      {{#each @model.note as |n|}}
        <UserNote @note={{n}} @removeNote={{this.removeNote}} />
      {{/each}}
    </DModal>
  </template>
}
