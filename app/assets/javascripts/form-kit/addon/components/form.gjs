import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { assert, debug, warn } from "@ember/debug";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import { modifier as modifierFn } from "ember-modifier";
import FkControlInputGroup from "form-kit/components/control/input-group";
import { VALIDATION_TYPES } from "form-kit/lib/constants";
import FieldData from "form-kit/lib/field-data";
import DButton from "discourse/components/d-button";
import FormErrors from "./form/errors";
import FormField from "./form/field";
import Row from "./row";

export default class Form extends Component {
  @tracked validationState = {};
  @tracked showAllValidations = false;

  fields = new Map();

  onValidation = modifierFn((element, [eventName, handler]) => {
    if (eventName) {
      element.addEventListener(eventName, handler);

      return () => element.removeEventListener(eventName, handler);
    }
  });

  constructor() {
    super(...arguments);

    this.args.onRegisterApi?.({
      submit: this.onSubmit,
      reset: this.onReset,
    });
  }

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
    if (!this.validationState) {
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
    set(this.effectiveData, key, value);

    if (this.fieldValidationEvent === VALIDATION_TYPES.change) {
      this.handleFieldValidation(key);
    }
  }

  @action
  registerField(name, field) {
    assert(
      `You didn't pass a name to the form field.`,
      typeof name !== "undefined"
    );

    assert(
      `You passed @name="${name}" to the form field, but this is already in use. Names of form fields must be unique!`,
      !this.fields.has(name)
    );

    this.fields.set(name, new FieldData(field));
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
    let name;

    if (typeof event === "string") {
      name = event;
    } else {
      const { target } = event;
      name = target.name;
    }

    console.log(event.target, name);

    if (name) {
      const field = this.fields.get(name);

      if (field) {
        await this._validate();
        field.validationEnabled = true;
      }
    } else if (event instanceof Event) {
      alert("???");
    }
  }

  async _validate() {
    this.validationState = await this.validate();
  }

  async validate() {
    let errors = {};
    for (const [name, field] of this.fields) {
      Object.assign(
        errors,
        await field.validate?.(
          name,
          this.effectiveData[name],
          this.effectiveData
        )
      );
    }

    return errors;
  }

  <template>
    <form
      novalidate
      class="d-form"
      ...attributes
      {{on "submit" this.onSubmit}}
      {{on "reset" this.onReset}}
      {{this.onValidation this.fieldValidationEvent this.handleFieldValidation}}
      {{this.onValidation
        this.fieldRevalidationEvent
        this.handleFieldRevalidation
      }}
    >
      {{yield
        (hash
          Row=(component Row)
          Errors=(component
            FormErrors errors=this.visibleErrors withPrefix=true
          )
          Field=(component
            FormField
            data=this.effectiveData
            set=this.set
            registerField=this.registerField
            unregisterField=this.unregisterField
            errors=this.validationState
          )
          InputGroup=(component
            FkControlInputGroup
            data=this.effectiveData
            set=this.set
            registerField=this.registerField
            unregisterField=this.unregisterField
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
