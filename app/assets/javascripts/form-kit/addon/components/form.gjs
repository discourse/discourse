import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { modifier as modifierFn } from "ember-modifier";
import FKContainer from "form-kit/components/container";
import FKControlConditionalContent from "form-kit/components/control/conditional-content";
import FKControlInputGroup from "form-kit/components/control/input-group";
import FKFormErrors from "form-kit/components/errors";
import FKField from "form-kit/components/field";
import Row from "form-kit/components/row";
import FKSection from "form-kit/components/section";
import { VALIDATION_TYPES } from "form-kit/lib/constants";
import FieldData from "form-kit/lib/field-data";
import DButton from "discourse/components/d-button";

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

  transientData = new TrackedObject({});

  constructor() {
    super(...arguments);

    this.args.onRegisterApi?.({
      submit: this.onSubmit,
      reset: this.onReset,
    });
  }

  @cached
  get effectiveData() {
    const obj = this.args.data ?? {};
    const { transientData } = this;

    return new Proxy(obj, {
      get(target, prop) {
        return prop in transientData
          ? transientData[prop]
          : Reflect.get(target, prop);
      },

      set(target, property, value) {
        return Reflect.set(transientData, property, value);
      },

      has(target, prop) {
        return prop in transientData ? true : Reflect.has(target, prop);
      },

      getOwnPropertyDescriptor(target, prop) {
        return Reflect.getOwnPropertyDescriptor(
          prop in transientData ? transientData : target,
          prop
        );
      },

      ownKeys(target) {
        return (
          [...Reflect.ownKeys(target), ...Reflect.ownKeys(transientData)]
            // return only unique values
            .filter((value, index, array) => array.indexOf(value) === index)
        );
      },

      deleteProperty(target, prop) {
        if (prop in transientData) {
          delete transientData[prop];
        }

        return true;
      },
    });
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

    return Object.keys(validationState).some(
      (name) => validationState[name].length
    );
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

    const fieldModel = new FieldData(name, field);
    this.fields.set(name, fieldModel);

    return fieldModel;
  }

  @action
  unregisterField(name) {
    this.fields.delete(name);
  }

  @action
  async onSubmit(event) {
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

    if (name) {
      const field = this.fields.get(name);

      if (field) {
        await this._validate();
        field.validationEnabled = true;
      }
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
      class="form-kit"
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
          Section=(component FKSection)
          ConditionalContent=(component FKControlConditionalContent)
          Errors=(component FKFormErrors errors=this.visibleErrors)
          Container=(component FKContainer)
          Button=(component DButton)
          Submit=(component
            DButton
            action=this.onSubmit
            forwardEvent=true
            class="btn-primary"
            label="submit"
            type="submit"
          )
          Field=(component
            FKField
            data=this.effectiveData
            set=this.set
            registerField=this.registerField
            unregisterField=this.unregisterField
            errors=this.validationState
          )
          InputGroup=(component
            FKControlInputGroup
            data=this.effectiveData
            set=this.set
            registerField=this.registerField
            unregisterField=this.unregisterField
            errors=this.validationState
          )
        )
        this.effectiveData
      }}
    </form>
  </template>
}
