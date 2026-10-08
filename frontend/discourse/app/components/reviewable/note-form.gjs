import Component from "@glimmer/component";
import { destroy } from "@ember/destroyable";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { modifier } from "ember-modifier";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserAutocompleteResults from "discourse/components/user-autocomplete-results";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { TextareaAutocompleteHandler } from "discourse/lib/textarea-text-manipulation";
import userSearch, { validateSearchResult } from "discourse/lib/user-search";
import dAutocomplete from "discourse/ui-kit/modifiers/d-autocomplete";
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
  @service a11y;
  @service appEvents;
  @service siteSettings;
  @service toasts;

  mentionAutocomplete = modifier((textarea) => {
    if (!this.siteSettings.enable_mentions) {
      return;
    }

    const textHandler = new TextareaAutocompleteHandler(textarea);
    const autocomplete = dAutocomplete.setupAutocomplete(
      getOwner(this),
      textarea,
      textHandler,
      {
        component: UserAutocompleteResults,
        key: UserAutocompleteResults.TRIGGER_KEY,
        dataSource: (term) => userSearch({ term, includeGroups: false }),
        transformComplete: (user) => {
          validateSearchResult(user);
          return user.username;
        },
        afterComplete: () => {
          textarea.focus({ preventScroll: true });
        },
        triggerRule: async () => !(await textHandler.inCodeBlock()),
      }
    );

    return () => destroy(autocomplete);
  });

  /**
   * Registers the Form API reference.
   *
   * @param {Object} api - The Form API object, with form helper methods.
   */
  @action
  registerApi(api) {
    this.formApi = api;
  }

  @bind
  onDirtyCheck() {
    return !isEmpty(this.formApi.get("content"));
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

      if (response.unnotified_usernames?.length) {
        const message = i18n("review.notes.mentions_not_notified", {
          count: response.unnotified_usernames.length,
          usernames: response.unnotified_usernames
            .map((username) => `@${username}`)
            .join(", "),
        });
        this.toasts.warning({
          duration: "long",
          data: { message },
        });
        this.a11y.announce(message, "polite");
      }

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
        class="reviewable-note-form__form"
        @data={{hash content=""}}
        @onDirtyCheck={{this.onDirtyCheck}}
        @onRegisterApi={{this.registerApi}}
        @onSubmit={{this.onSubmit}}
        as |form|
      >
        <form.Field
          @format="full"
          @name="content"
          @title={{i18n "review.notes.add_note_description"}}
          @type="textarea"
          @validation="required:trim|length:1,2000"
          as |field|
        >
          <div class="reviewable-note-form__textarea-wrapper">
            <field.Control
              class="reviewable-note-form__textarea"
              placeholder={{i18n "review.notes.placeholder"}}
              @height={{80}}
              {{this.mentionAutocomplete}}
            />
            <PluginOutlet
              @connectorTagName="div"
              @name="reviewable-note-form-after-note"
              @outletArgs={{lazyHash form=form reviewable=@reviewable}}
            />
          </div>
        </form.Field>

        <form.Actions>
          <form.Submit
            class="btn-small btn-primary"
            @label="review.notes.add_note_button"
          />
        </form.Actions>
      </Form>
    </div>
  </template>
}
