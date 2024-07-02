import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { ImmerChangeset } from "ember-immer-changeset";
import { modifier as modifierFn } from "ember-modifier";
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
import I18n from "I18n";

export default class FKForm extends Component {
  @service dialog;
  @service router;

  @tracked isLoading = false;

  fields = new Map();

  isDirtyForm = false;

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

  get mutable() {
    return this.args.mutable ?? false;
  }

  @action
  checkIsDirty(transition) {
    if (
      this.isDirtyForm &&
      !transition.isAborted &&
      !transition.queryParamsOnly
    ) {
      transition.abort();

      this.dialog.yesNoConfirm({
        message: I18n.t("form_kit.dirty_form"),
        didConfirm: () => {
          this.isDirtyForm = false;
          this.onReset();
          transition.retry();
        },
      });
    }
  }

  @cached
  get effectiveData() {
    return new ImmerChangeset(this.args.data ?? {});

    // if (this.mutable) {
    //   return obj;
    // }
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

  get hasErrors() {
    return Array.from(this.fields.values()).some((field) => field.hasErrors);
  }

  get errors() {
    const errors = {};
    for (const [name, field] of this.fields) {
      errors[name] = field.errors;
    }
    return errors;
  }

  @action
  addError(name, message) {
    this.effectiveData.addError({ name, key: name, message });
    // const field = this.fields.get(name);
    // field?.pushError(message);
  }

  @action
  async push(name, value) {
    const current = this.effectiveData.get(name) ?? [];
    this.effectiveData.set(name, current.concat(value ?? {}));
  }

  @action
  async remove(name, index) {
    const current = this.effectiveData.get(name) ?? [];

    const keys = [];
    for (const [n] of this.fields) {
      if (n.startsWith(`${name}.${index}`)) {
        keys.push(n.split(".").pop());
      }
    }

    this.effectiveData.set(
      name,
      current.filter((_, i) => i !== index)
    );

    const newMap = new Map();
    let newIndex = 0;
    for (const [n, field] of this.fields) {
      // keys.forEach((key) => {
      //   if (n.endsWith(`.${key}`)) {
      //     newMap.set(`${name}.${newIndex}.${key}`, field);
      //   }
      // });

      newIndex++;
    }

    this.fields = newMap;

    this.effectiveData.removeErrors();

    console.log(this.effectiveData, this.fields);
  }

  @action
  async set(name, value, { index }) {
    this.isDirtyForm = true;

    this.effectiveData.set(name, value);

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
      // throw new Error(
      //   `@name="${name}", is already in use. Names of \`<form.Field />\` must be unique!`
      // );

      return this.fields.get(name);
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

    await this.validate(this.fields);

    if (!this.hasErrors) {
      this.isDirtyForm = false;
      await this.args.onSubmit?.(this.effectiveData);
    }
  }

  @action
  async onReset(event) {
    event?.preventDefault();

    for (const key of Object.keys(this.transientData)) {
      delete this.transientData[key];
    }

    this.effectiveData.removeErrors();

    await this.args.onReset?.(this.effectiveData);

    await new Promise((resolve) => next(resolve));
  }

  @action
  async triggerRevalidationFor(name) {
    const field = this.fields.get(name);

    if (!field) {
      return;
    }

    await this.validate(new Map([[name, field]]));
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
    // this.isLoading = true;

    this.effectiveData.removeErrors();

    await this.effectiveData.validate(async (draftData) => {
      for (const [name, field] of fields) {
        await field.validate?.(name, this.effectiveData.get(name), draftData);

        await this.args.validate?.(draftData, {
          addError: this.addError,
        });
      }
    });

    // try {
    //   for (const [name, field] of fields) {
    //     await field.validate?.(
    //       name,
    //       this.effectiveData[name],
    //       this.effectiveData
    //     );
    //   }

    //   await this.args.validate?.(this.effectiveData, {
    //     addError: this.addError,
    //   });

    //   this.fieldsWithErrors = Array.from(this.fields.values()).filter(
    //     (field) => field.hasErrors
    //   );
    // } finally {
    //   this.isLoading = false;
    // }
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
      <FKErrorsSummary @errors={{this.effectiveData.errors}} />

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
            isLoading=this.isLoading
          )
          Field=(component
            FKField
            errors=this.effectiveData.errors
            addError=this.addError
            data=this.effectiveData.draftData
            set=this.set
            registerField=this.registerField
            unregisterField=this.unregisterField
            triggerRevalidationFor=this.triggerRevalidationFor
          )
          Collection=(component
            FKCollection
            errors=this.effectiveData.errors
            addError=this.addError
            data=this.effectiveData.draftData
            effectiveData=this.effectiveData
            set=this.set
            remove=this.remove
            registerField=this.registerField
            unregisterField=this.unregisterField
            triggerRevalidationFor=this.triggerRevalidationFor
          )
          InputGroup=(component
            FKControlInputGroup
            data=this.effectiveData
            set=this.set
            registerField=this.registerField
            unregisterField=this.unregisterField
          )
          set=this.set
          push=this.push
        )
        this.effectiveData.draftData
      }}
    </form>
  </template>
}
