import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { assert, debug, warn } from "@ember/debug";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import FieldData from "form-kit/lib/field-data";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import FormField from "./form/field";

export default class Form extends Component {
  @tracked validationState = {};

  fields = new Map();

  @cached
  get effectiveData() {
    return this.args.data ?? {};
  }

  get hasValidationErrors() {
    const { validationState } = this;

    if (!validationState) {
      return false;
    }

    return Object.keys(validationState).some((name) => this.fields.has(name));
  }

  @action
  set(key, value) {
    set(this.effectiveData, key, value);
  }

  @action
  registerField(name, field, validation) {
    assert(
      `You didn't pass a name to the form field.`,
      typeof name !== "undefined"
    );

    assert(
      `You passed @name="${name}" to the form field, but this is already in use. Names of form fields must be unique!`,
      !this.fields.has(name)
    );
    this.fields.set(name, new FieldData(field, validation));
  }

  @action
  async onSubmit(event) {
    debug("OnSubmit form");

    event?.preventDefault();

    await this._validate();
    this.showAllValidations = true;

    if (!this.hasValidationErrors) {
      this.args.onSubmit?.(this.effectiveData);
    }
  }

  /**
   * Handle the `@validateOn` event for a certain field, e.g. "blur".
   * Associating the event with a field is done by looking at the event target's `name` attribute, which must match one of the `<form.field @name="...">` invocations by the user's template.
   * Validation will be triggered, and the particular field will be marked to show eventual validation errors.
   */
  @action
  async handleFieldValidation(event) {
    let name;

    if (typeof event === "string") {
      name = event;
    } else {
      const { target } = event;

      name = target.name;
    }

    if (name) {
      const field = this.fields.get(name);

      if (field) {
        await this._validate();
        field.validationEnabled = true;
      }
    } else if (event instanceof Event) {
      warn(
        `An event of type "${event.type}" was received by headless-form, which is supposed to trigger validations for a certain field. But the name of that field could not be determined. Make sure that your control element has a \`name\` attribute matching the field, or use the yielded \`{{field.captureEvents}}\` to capture the events.`,
        { id: "headless-form.validation-event-for-unknown-field" }
      );
    }
  }

  async _validate() {
    this.validationState = await this.validate();
  }

  async validate() {
    debug("Validating form");

    const customFieldValidations = [];
    for (const [name, field] of this.fields) {
      const fieldValidationResult = await field.validate?.(
        this.effectiveData[name],
        name,
        this.effectiveData
      );

      if (fieldValidationResult) {
        customFieldValidations.push({
          [name]: fieldValidationResult,
        });
      }
    }

    return customFieldValidations[0];
  }

  <template>
    <form
      class={{concatClass "d-form"}}
      {{on "submit" this.onSubmit}}
      novalidate
    >
      {{#if this.hasValidationErrors}}
        {{log this.validationState}}
        ERROR
      {{/if}}

      {{yield
        (hash
          Field=(component
            FormField
            data=this.effectiveData
            set=this.set
            triggerValidationFor=this.handleFieldValidation
            registerField=this.registerField
            errors=this.validationState
          )
        )
      }}

      <DButton
        class="d-form__submit btn-primary"
        @label="Submit"
        @action={{this.onSubmit}}
      />
    </form>
  </template>
}
