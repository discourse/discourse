import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

/**
 * A form component for adding notes to Reviewable items.
 *
 * @component ReviewableNoteForm
 *
 * @param {Reviewable} reviewable - The Reviewable that the note will be attached to.
 * @param {Function} [onNoteCreated] - Callback function called when a note is successfully created.
 */
export default class ReviewableNoteForm extends Component {
  @service appEvents;
  @service currentUser;

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
    if (!data.content?.trim()) {
      return;
    }

    try {
      const response = await ajax(`/review/${this.args.reviewable.id}/notes`, {
        type: "POST",
        data: {
          reviewable_note: {
            content: data.content.trim(),
          },
        },
      });

      // Clear the submitted content
      await this.formApi.set("content", "");

      // Notify any interested plugins that a note has been created.
      this.appEvents.trigger(
        "reviewablenote:created",
        data,
        this.args.reviewable,
        this.formApi
      );

      // Notify parent component
      if (this.args.onNoteCreated) {
        this.args.onNoteCreated(response);
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="reviewable-note-form">
      <Form
        @data={{hash content=""}}
        @onSubmit={{this.onSubmit}}
        @onRegisterApi={{this.registerApi}}
        class="reviewable-note-form__form"
        as |form|
      >
        <form.Field
          @name="content"
          @title={{i18n "review.notes.add_note_description"}}
          @format="full"
          @validation="required:trim|length:1,2000"
          as |field|
        >
          <div class="reviewable-note-form__textarea-wrapper">
            <field.Textarea
              placeholder={{i18n "review.notes.placeholder"}}
              class="reviewable-note-form__textarea"
              rows="4"
            />
          </div>
        </form.Field>

        <PluginOutlet
          @name="reviewable-note-form-after-note"
          @connectorTagName="div"
          @outletArgs={{lazyHash form=form}}
        />

        <form.Actions>
          <form.Submit
            @label="review.notes.add_note_button"
            class="btn-primary"
          />
        </form.Actions>
      </Form>
    </div>
  </template>
}
