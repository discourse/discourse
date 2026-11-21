import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import FormDefinitionEditor from "discourse/components/form-definition-editor";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import {
  notifyRegistrationFormCreated,
  saveRegistrationForm,
} from "../lib/registration-forms.js";
import DeleteRegistrationFormButton from "./delete-registration-form-button.gjs";
import EventRegistration from "./modal/event-registration.gjs";

function validateQuestions({ fields }, { addError, removeError }) {
  const fieldName = "fields.0.type";
  removeError(fieldName);
  if (!fields.some((field) => field.type !== "display_text")) {
    addError(fieldName, {
      title: i18n("form_definition.type"),
      message: i18n("event_registration.library.needs_answer_field"),
    });
  }
}

export default class EventRegistrationFormEditor extends Component {
  @service modal;

  @tracked savedForm;

  @action
  preview(definition) {
    this.modal.show(EventRegistration, { model: { definition } });
  }

  @action
  async save(definition) {
    try {
      this.savedForm = await saveRegistrationForm(
        this.args.record.id,
        definition
      );
      if (!this.args.record.id) {
        notifyRegistrationFormCreated(this.savedForm);
      }
      this.args.onFinished?.();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    {{#if this.savedForm}}
      {{yield this.savedForm.definition.title}}
    {{else}}
      <p>{{i18n "event_registration.host_notice"}}</p>
      {{#if @record.has_linked_events}}
        <p class="alert alert-info">{{i18n
            "event_registration.library.existing_events_keep_version"
          }}</p>
      {{/if}}
      <FormDefinitionEditor
        @actionsWidthSource={{@actionsWidthSource}}
        @definition={{@record.definition}}
        @floatingActions={{true}}
        @minimumFields={{1}}
        @onPreview={{this.preview}}
        @onSave={{this.save}}
        @validate={{validateQuestions}}
      >
        <:details as |form|>
          <form.Field
            @format="full"
            @name="title"
            @title={{trustHTML
              (i18n "event_registration.library.private_title")
            }}
            @type="input"
            @validation="required:trim"
            as |field|
          >
            <field.Control maxlength="255" />
          </form.Field>
          <form.Field
            class="event-registration-form-editor__description"
            @format="full"
            @name="description"
            @showOptional={{false}}
            @title={{trustHTML
              (i18n "event_registration.library.private_description")
            }}
            @type="input"
            as |field|
          >
            <field.Control maxlength="2000" />
          </form.Field>
        </:details>
        <:additionalActions>
          {{#if @record.id}}
            <DeleteRegistrationFormButton
              class="btn-danger event-registration-form-editor__delete"
              @formId={{@record.id}}
              @formTitle={{@record.definition.title}}
              @inUse={{@record.in_use}}
              @label="delete"
              @onDeleted={{@onFinished}}
            />
          {{/if}}
        </:additionalActions>
      </FormDefinitionEditor>
    {{/if}}
  </template>
}
