import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import UserLink from "discourse/components/user-link";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import avatar from "discourse/helpers/avatar";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

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
        <div class="user-note">
          <div class="posted-by">
            <UserLink @user={{n.created_by}}>
              {{avatar n.created_by imageSize="small"}}
            </UserLink>
          </div>
          <div class="note-contents">
            <div class="note-info">
              <span class="username">{{n.created_by.username}}</span>
              <span class="post-date">{{ageWithTooltip n.created_at}}</span>

              {{#if n.can_delete}}
                <span class="controls">
                  <DButton
                    @action={{fn this.removeNote n}}
                    @icon="far-trash-can"
                    @title="user_notes.remove"
                    class="btn-small btn-danger"
                  />
                </span>
              {{/if}}
            </div>

            <div class="cooked">
              <CookText @rawText={{n.raw}} />
            </div>

            {{#if n.post_id}}
              <a href={{n.post_url}} class="btn btn-small">
                {{i18n "user_notes.show_post"}}
              </a>
            {{/if}}
          </div>

          <div class="clearfix"></div>
        </div>
      {{/each}}
    </DModal>
  </template>
}
