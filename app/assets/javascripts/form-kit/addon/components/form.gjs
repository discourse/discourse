import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { assert, debug, warn } from "@ember/debug";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { TrackedMap } from "@ember-compat/tracked-built-ins";
import { modifier as modifierFn } from "ember-modifier";
import { VALIDATION_TYPES } from "form-kit/lib/constants";
import FieldData from "form-kit/lib/field-data";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import FormField from "./form/field";

export default class Form extends Component {
  @tracked validationState = {};
  @tracked showAllValidations = false;
  @tracked fields = new TrackedMap();

  onValidation = modifierFn((element, [eventName, handler]) => {
    if (eventName) {
      element.addEventListener(eventName, handler);

      return () => element.removeEventListener(eventName, handler);
    }
  });

  @cached
  get effectiveData() {
    return this.args.data ?? {};
  }

  get validateOn() {
    return this.args.validateOn ?? VALIDATION_TYPES.submit;
  }

  get revalidateOn() {
    return this.args.revalidateOn ?? VALIDATION_TYPES.change;
  }

  get fieldValidationEvent() {
    const { validateOn } = this;

    console.log({ validateOn });

    if (validateOn === VALIDATION_TYPES.submit) {
      return undefined;
    }

    return validateOn;
  }

  get hasValidationErrors() {
    const { validationState } = this;

    if (!validationState) {
      return false;
    }

    return Object.keys(validationState).some((name) => this.fields.has(name));
  }

  get fieldRevalidationEvent() {
    const { validateOn, revalidateOn } = this;

    if (revalidateOn === VALIDATION_TYPES.submit) {
      return undefined;
    }

    if (
      validateOn === VALIDATION_TYPES.input ||
      (validateOn === VALIDATION_TYPES.change &&
        revalidateOn === VALIDATION_TYPES.focusout) ||
      validateOn === revalidateOn
    ) {
      return undefined;
    }

    return revalidateOn;
  }

  get visibleErrors() {
    if (!this.validationState?.isResolved) {
      return;
    }

    const visibleErrors = {};

    for (const [field, errors] of Object.entries(this.validationState)) {
      if (this.showErrorsFor(field)) {
        visibleErrors[field] = errors;
      }
    }

    return visibleErrors;
  }

  showErrorsFor(field) {
    return (
      this.showAllValidations ||
      (this.fields.get(field)?.validationEnabled ?? false)
    );
  }

  @action
  set(key, value) {
    console.log("set", key, value);
    set(this.effectiveData, key, value);
    console.log(this.effectiveData);
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

    const f = new FieldData(field, validation);
    this.fields.set(name, f);
    return f;
  }

  @action
  unregisterField(name) {
    this.fields.delete(name);
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

  @action
  async onReset(event) {
    event?.preventDefault();

    this.validationState = undefined;
    this.submissionState = undefined;
  }

  @action
  async handleFieldValidation(event) {
    console.log("handleFieldValidation", event);
    let name;

    if (typeof event === "string") {
      name = event;
    } else {
      const { target } = event;
      name = target.name;
    }

    if (name) {
      console.log(name);
      const field = this.fields.get(name);

      if (field) {
        console.log(field);
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
      class="d-form"
      {{on "submit" this.onSubmit}}
      {{on "reset" this.onReset}}
      {{this.onValidation this.fieldValidationEvent this.handleFieldValidation}}
      {{this.onValidation
        this.fieldRevalidationEvent
        this.handleFieldRevalidation
      }}
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
            unregisterField=this.unregisterField
            errors=this.validationState
            fields=this.fields
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
