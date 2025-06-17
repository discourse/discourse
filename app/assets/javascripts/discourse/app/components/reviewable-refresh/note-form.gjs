import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Textarea } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
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
  @service currentUser;

  /**
   * The current content of the note being composed.
   *
   * @type {string}
   */
  @tracked content = "";

  /**
   * Whether the form is currently being submitted.
   *
   * @type {boolean}
   */
  @tracked isSubmitting = false;

  /**
   * Handles form submission to create a new reviewable note.
   *
   * @param {Event} [event] - Form submit event (optional)
   */
  @action
  async onSubmit(event) {
    event?.preventDefault();

    if (!this.content.trim()) {
      return;
    }

    this.isSubmitting = true;

    try {
      const response = await ajax(
        `/reviewables/${this.args.reviewable.id}/notes`,
        {
          type: "POST",
          data: {
            reviewable_note: {
              content: this.content.trim(),
            },
          },
        }
      );

      // Clear the form
      this.content = "";

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
      this.onSubmit(event);
    }
  }

  /**
   * Whether the form has valid content to submit
   *
   * @returns {boolean} True if content is not empty after trimming
   */
  get isValid() {
    return this.content.trim().length > 0;
  }

  /**
   * Number of characters remaining before hitting the limit
   *
   * @returns {number} Characters remaining out of 2000 max
   */
  get remainingChars() {
    const maxLength = 2000;
    return maxLength - this.content.length;
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
      <div class="reviewable-note-form__header">
        {{i18n "review.notes.add_note_description"}}
      </div>

      <form {{on "submit" this.onSubmit}} class="reviewable-note-form__form">
        <div class="reviewable-note-form__textarea-wrapper">
          <Textarea
            {{on "keydown" this.onKeyDown}}
            @value={{this.content}}
            placeholder={{i18n "review.notes.placeholder"}}
            class="reviewable-note-form__textarea"
            rows="4"
            maxlength="2000"
            disabled={{this.isSubmitting}}
          />

          {{#if this.content}}
            <div
              class="reviewable-note-form__char-count
                {{if this.isNearLimit 'warning'}}"
            >
              {{i18n "review.notes.chars_remaining" count=this.remainingChars}}
            </div>
          {{/if}}
        </div>

        <div class="reviewable-note-form__actions">
          <DButton
            @action={{this.onSubmit}}
            @disabled={{not this.isValid}}
            @isLoading={{this.isSubmitting}}
            @label="review.notes.add_note_button"
            class="btn-primary"
          />
        </div>
      </form>
    </div>
  </template>
}
