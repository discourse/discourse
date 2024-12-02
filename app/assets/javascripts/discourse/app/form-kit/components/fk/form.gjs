import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import FKAlert from "discourse/form-kit/components/fk/alert";
import FKCheckboxGroup from "discourse/form-kit/components/fk/checkbox-group";
import FKCollection from "discourse/form-kit/components/fk/collection";
import FKContainer from "discourse/form-kit/components/fk/container";
import FKControlConditionalContent from "discourse/form-kit/components/fk/control/conditional-content";
import FKErrorsSummary from "discourse/form-kit/components/fk/errors-summary";
import FKField from "discourse/form-kit/components/fk/field";
import FKFieldset from "discourse/form-kit/components/fk/fieldset";
import FKInputGroup from "discourse/form-kit/components/fk/input-group";
import Row from "discourse/form-kit/components/fk/row";
import FKSection from "discourse/form-kit/components/fk/section";
import FKSubmit from "discourse/form-kit/components/fk/submit";
import { VALIDATION_TYPES } from "discourse/form-kit/lib/constants";
import FKFormData from "discourse/form-kit/lib/fk-form-data";
import { i18n } from "discourse-i18n";

class FKForm extends Component {
  @service dialog;
  @service router;

  @tracked isValidating = false;

  @tracked isSubmitting = false;

  fields = new Map();

  formData = new FKFormData(this.args.data ?? {});

  constructor() {
    super(...arguments);

    this.args.onRegisterApi?.({
      set: this.set,
      setProperties: this.setProperties,
      submit: this.onSubmit,
      reset: this.onReset,
      addError: this.addError,
      removeError: this.removeError,
    });

    this.router.on("routeWillChange", this.checkIsDirty);
  }

  willDestroy() {
    super.willDestroy();

    this.router.off("routeWillChange", this.checkIsDirty);
  }

  @action
  async checkIsDirty(transition) {
    if (
      this.formData.isDirty &&
      !transition.isAborted &&
      !transition.queryParamsOnly
    ) {
      transition.abort();

      this.dialog.yesNoConfirm({
        message: i18n("form_kit.dirty_form"),
        didConfirm: async () => {
          await this.onReset();
          transition.retry();
        },
      });
    }
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

  @action
  addError(name, { title, message }) {
    this.formData.addError(name, {
      title,
      message,
    });
  }

  @action
  removeError(name) {
    this.formData.removeError(name);
  }

  @action
  async addItemToCollection(name, value = {}) {
    const current = this.formData.get(name) ?? [];
    this.formData.set(name, current.concat(value));
  }

  @action
  async remove(name, index) {
    const current = this.formData.get(name) ?? [];

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
      await this.triggerRevalidationFor(name);
    }
  }

  @action
  async setProperties(object) {
    for (const [name, value] of Object.entries(object)) {
      await this.set(name, value);
    }
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

    this.fields.set(name, field);

    return field;
  }

  @action
  unregisterField(name) {
    this.fields.delete(name);
    this.removeError(name);
  }

  @action
  async onSubmit(event) {
    event?.preventDefault();

    if (this.isSubmitting) {
      return;
    }

    try {
      this.isSubmitting = true;

      await this.validate(this.fields.values());

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

    if (this.formData.errors[name]) {
      await this.validate([field]);
    }
  }

  async validate(fields) {
    if (this.isValidating) {
      return;
    }

    this.isValidating = true;

    try {
      for (const field of fields) {
        this.formData.removeError(field.name);

        await field.validate?.(
          field.name,
          this.formData.get(field.name),
          this.formData.draftData
        );
      }

      await this.args.validate?.(this.formData.draftData, {
        addError: this.addError,
        removeError: this.removeError,
      });
    } finally {
      this.isValidating = false;
    }
  }

  <template>
    <form
      novalidate
      class="form-kit"
      ...attributes
      {{on "submit" this.onSubmit}}
      {{on "reset" this.onReset}}
    >
      <FKErrorsSummary @errors={{this.formData.errors}} />

      {{yield
        (hash
          Row=Row
          Section=FKSection
          Fieldset=FKFieldset
          ConditionalContent=(component FKControlConditionalContent)
          Container=FKContainer
          Actions=(component FKSection class="form-kit__actions")
          Button=(component DButton class="form-kit__button")
          Alert=FKAlert
          Submit=(component
            FKSubmit
            action=this.onSubmit
            forwardEvent=true
            class="btn-primary form-kit__button"
            type="submit"
            isLoading=this.isSubmitting
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
            data=this.formData
            set=this.set
            registerField=this.registerField
            unregisterField=this.unregisterField
            triggerRevalidationFor=this.triggerRevalidationFor
          )
          Collection=(component
            FKCollection
            errors=this.formData.errors
            addError=this.addError
            data=this.formData
            set=this.set
            remove=this.remove
            registerField=this.registerField
            unregisterField=this.unregisterField
            triggerRevalidationFor=this.triggerRevalidationFor
          )
          InputGroup=(component
            FKInputGroup
            errors=this.formData.errors
            addError=this.addError
            data=this.formData
            set=this.set
            remove=this.remove
            registerField=this.registerField
            unregisterField=this.unregisterField
            triggerRevalidationFor=this.triggerRevalidationFor
          )
          CheckboxGroup=(component
            FKCheckboxGroup
            errors=this.formData.errors
            addError=this.addError
            data=this.formData
            set=this.set
            remove=this.remove
            registerField=this.registerField
            unregisterField=this.unregisterField
            triggerRevalidationFor=this.triggerRevalidationFor
          )
          set=this.set
          setProperties=this.setProperties
          addItemToCollection=this.addItemToCollection
        )
        this.formData.draftData
      }}
    </form>
  </template>
}

const Form = <template>
  {{#each (array @data) as |data|}}
    <FKForm
      @data={{data}}
      @onSubmit={{@onSubmit}}
      @validate={{@validate}}
      @validateOn={{@validateOn}}
      @onRegisterApi={{@onRegisterApi}}
      @onReset={{@onReset}}
      ...attributes
      as |components draftData|
    >
      {{yield components draftData}}
    </FKForm>
  {{/each}}
</template>;

export default Form;
