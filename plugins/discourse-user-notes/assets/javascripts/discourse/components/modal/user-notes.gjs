import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { applyValueTransformer } from "discourse/lib/transformer";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import UserNote from "../user-note";

export default class UserNotesModal extends Component {
  @service dialog;
  @service store;

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

    const args = {
      raw: data.content,
      user_id: parseInt(this.args.model.userId, 10),
    };

    if (this.args.model.postId) {
      args.post_id = parseInt(this.args.model.postId, 10);
    }

    try {
      await note.save(args);
      await this.formApi.set("content", "");
      this.args.model.note.unshift(note);
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
            removeValueFromArray(this.args.model.note, note);
            this.#refreshCount();
          })
          .catch(popupAjaxError);
      },
    });
  }

  #refreshCount() {
    this.args.model.callback?.(this.args.model.note.length);
  }

  <template>
    <DModal
      class="user-notes-modal"
      @closeModal={{@closeModal}}
      @subtitle={{this.subtitle}}
      @title={{i18n "user_notes.title"}}
    >
      <Form
        @onRegisterApi={{this.registerApi}}
        @onSubmit={{this.onSubmit}}
        as |form|
      >
        <form.Field
          @format="full"
          @name="content"
          @title={{i18n "user_notes.attach_note_description"}}
          @type="textarea"
          @validation="required:trim"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Actions>
          <form.Submit class="btn-primary" @label="user_notes.attach" />
        </form.Actions>
      </Form>

      {{#each @model.note as |n|}}
        <UserNote @note={{n}} @removeNote={{this.removeNote}} />
      {{/each}}
    </DModal>
  </template>
}
