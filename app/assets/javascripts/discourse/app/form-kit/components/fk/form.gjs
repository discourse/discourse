import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import FKAlert from "discourse/form-kit/components/fk/alert";
import FKCollection from "discourse/form-kit/components/fk/collection";
import FKContainer from "discourse/form-kit/components/fk/container";
import FKControlConditionalContent from "discourse/form-kit/components/fk/control/conditional-content";
import FKControlInputGroup from "discourse/form-kit/components/fk/control/input-group";
import FKErrorsSummary from "discourse/form-kit/components/fk/errors-summary";
import FKField from "discourse/form-kit/components/fk/field";
import Row from "discourse/form-kit/components/fk/row";
import FKSection from "discourse/form-kit/components/fk/section";
import { VALIDATION_TYPES } from "discourse/form-kit/lib/constants";
import FieldData from "discourse/form-kit/lib/field-data";
import FormData from "discourse/form-kit/lib/form-data";
import I18n from "I18n";

export default class FKForm extends Component {
  @service dialog;
  @service router;

  @tracked isLoading = false;

  @tracked isSubmitting = false;

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
      set: this.set,
      submit: this.onSubmit,
      reset: this.onReset,
    });

    this.router.on("routeWillChange", this.checkIsDirty);
  }

  willDestroy() {
    super.willDestroy();

    this.router.off("routeWillChange", this.checkIsDirty);
  }

  @action
  checkIsDirty(transition) {
    if (
      this.formData.isDirty &&
      !transition.isAborted &&
      !transition.queryParamsOnly
    ) {
      transition.abort();

      this.dialog.yesNoConfirm({
        message: I18n.t("form_kit.dirty_form"),
        didConfirm: () => {
          this.onReset();
          transition.retry();
        },
      });
    }
  }

  // @cached
  // get effectiveData() {
  //   return new EffectiveData(this.args.data ?? {});

  @cached
  get formData() {
    return new FormData(this.args.data ?? {});
  }

  get validateOn() {
    return this.args.validateOn ?? VALIDATION_TYPES.submit;
  }

  get fieldValidationEvent() {
    const { validateOn } = this;

    if (validateOn === VALIDATION_TYPES.submit) {
      return undefined;
    }

    return validateOn;
  }

  get errors() {
    const errors = {};
    for (const [name, field] of this.fields) {
      errors[name] = field.errors;
    }
    return errors;
  }

  @action
  addError(name, { title, message }) {
    this.formData.addError(name, {
      title,
      message,
    });
  }

  @action
  async addItemToCollection(name, value = {}) {
    const current = get(this.formData.draftData, name) ?? [];
    this.formData.set(name, current.concat(value));
  }

  @action
  async remove(name, index) {
    const current = get(this.formData.draftData, name) ?? [];

    this.formData.set(
      name,
      current.filter((_, i) => i !== index)
    );

    Object.keys(this.formData.errors).forEach((key) => {
      if (key.startsWith(`${name}.${index}.`)) {
        this.formData.removeError(key);
      }
    });
  }

  @action
  async set(name, value) {
    this.formData.set(name, value);

    if (this.fieldValidationEvent === VALIDATION_TYPES.change) {
      await this.handleFieldValidation(name);
    }

    await new Promise((resolve) => next(resolve));
  }

  @action
  registerField(name, field) {
    if (!name) {
      throw new Error("@name is required on `<form.Field />`.");
    }

    if (this.fields.has(name)) {
      throw new Error(
        `@name="${name}", is already in use. Names of \`<form.Field />\` must be unique!`
      );
    }

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

    if (this.isSubmitting) {
      return;
    }

    try {
      this.isSubmitting = true;

      await this.validate(this.fields);

      if (this.formData.isValid) {
        this.formData.save();

        await this.args.onSubmit?.(this.formData.draftData);
      }
    } finally {
      this.isSubmitting = false;
    }
  }

  @action
  async onReset(event) {
    event?.preventDefault();

    this.formData.removeErrors();
    await this.formData.rollback();
    await this.args.onReset?.(this.formData.draftData);
  }

  @action
  async triggerRevalidationFor(name) {
    const field = this.fields.get(name);

    if (!field) {
      return;
    }

    await this.validate(this.fields);
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
        await this.validate(this.fields);
      }
    }
  }

  async validate(fields) {
    this.isLoading = true;

    this.formData.removeErrors();

    try {
      for (const [name, field] of fields) {
        await field.validate?.(
          name,
          get(this.formData.draftData, name),
          this.formData.draftData
        );
      }

      await this.args.validate?.(this.formData.draftData, {
        addError: this.addError,
      });
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    <form
      novalidate
      class="form-kit"
      ...attributes
      {{on "submit" this.onSubmit}}
      {{on "reset" this.onReset}}
      {{this.onValidation this.fieldValidationEvent this.handleFieldValidation}}
    >
      <FKErrorsSummary @errors={{this.formData.errors}} />

      {{yield
        (hash
          Row=Row
          Section=FKSection
          ConditionalContent=(component FKControlConditionalContent)
          Container=FKContainer
          Actions=(component FKSection class="form-kit__actions")
          Button=(component DButton class="form-kit__button")
          Alert=FKAlert
          Submit=(component
            DButton
            action=this.onSubmit
            forwardEvent=true
            class="btn-primary form-kit__button"
            label="submit"
            type="submit"
            isLoading=(or this.isLoading this.isSubmitting)
          )
          Reset=(component
            DButton
            action=this.onReset
            forwardEvent=true
            class="form-kit__button"
            label="form_kit.reset"
          )
          Field=(component
            FKField
            errors=this.formData.errors
            addError=this.addError
            data=this.formData.draftData
            set=this.set
            registerField=this.registerField
            unregisterField=this.unregisterField
            triggerRevalidationFor=this.triggerRevalidationFor
          )
          Collection=(component
            FKCollection
            errors=this.formData.errors
            addError=this.addError
            data=this.formData.draftData
            set=this.set
            remove=this.remove
            registerField=this.registerField
            unregisterField=this.unregisterField
            triggerRevalidationFor=this.triggerRevalidationFor
          )
          InputGroup=(component
            FKControlInputGroup
            data=this.formData.draftData
            set=this.set
            registerField=this.registerField
            unregisterField=this.unregisterField
          )
          set=this.set
          addItemToCollection=this.addItemToCollection
        )
        this.formData.draftData
      }}
    </form>
  </template>
}
