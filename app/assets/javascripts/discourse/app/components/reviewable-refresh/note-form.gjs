import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { not } from "truth-helpers";
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
   * Whether the form is currently being submitted.
   *
   * @type {boolean}
   */
  @tracked isSubmitting = false;

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

    this.isSubmitting = true;

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
    } finally {
      this.isSubmitting = false;
    }
  }

  /**
   * Handles keyboard shortcuts in the textarea
   *
   * @param {KeyboardEvent} event - Keyboard event
   */
  @action
  onKeyDown(event) {
    // Ctrl/Cmd + Enter to submit
    if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
      event.preventDefault();
      this.formApi.submit();
    }
  }

  /**
   * Whether the form has valid content to submit
   *
   * @returns {boolean} True if content is not empty after trimming
   */
  get isValid() {
    const content = this.formApi.get("content") || "";
    return content.trim().length > 0;
  }

  /**
   * Number of characters remaining before hitting the limit
   *
   * @returns {number} Characters remaining out of 2000 max
   */
  get remainingChars() {
    const maxLength = 2000;
    const content = this.formApi.get("content") || "";
    return maxLength - content.trim().length;
  }

  /**
   * Whether the user is approaching the character limit
   *
   * @returns {boolean} True if less than 100 characters remaining
   */
  get isNearLimit() {
    return this.remainingChars < 100;
  }

  <template>
    <div class="reviewable-note-form">
      <Form
        @data={{hash content=""}}
        @onSubmit={{this.onSubmit}}
        @onRegisterApi={{this.registerApi}}
        class="reviewable-note-form__form"
        as |form data|
      >
        <form.Field
          @name="content"
          @title={{i18n "review.notes.add_note_description"}}
          @format="full"
          @validation="required"
          as |field|
        >
          <div class="reviewable-note-form__textarea-wrapper">
            <field.Textarea
              {{on "keydown" this.onKeyDown}}
              placeholder={{i18n "review.notes.placeholder"}}
              class="reviewable-note-form__textarea"
              rows="4"
              maxlength="2000"
              disabled={{this.isSubmitting}}
            />

            {{#if data.content}}
              <div
                class="reviewable-note-form__char-count{{if
                    this.isNearLimit
                    ' warning'
                  }}"
              >
                {{i18n
                  "review.notes.chars_remaining"
                  count=this.remainingChars
                }}
              </div>
            {{/if}}
          </div>
        </form.Field>

        <PluginOutlet
          @name="reviewable-note-form-after-note"
          @connectorTagName="div"
          @outletArgs={{lazyHash form=form}}
        />

        <form.Actions>
          <form.Submit
            @disabled={{not this.isValid}}
            @isLoading={{this.isSubmitting}}
            @label="review.notes.add_note_button"
            class="btn-primary"
          />
        </form.Actions>
      </Form>
    </div>
  </template>
}
