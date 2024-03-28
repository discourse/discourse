import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import DObject, { attr } from "discourse/lib/d-object";

export default class Wizard extends DObject {
  static async load(owner) {
    return Wizard.parse(owner, (await ajax({ url: "/wizard.json" })).wizard);
  }

  static parse(owner, { current_color_scheme, steps, ...payload }) {
    return new Wizard(owner, {
      ...payload,
      currentColorScheme: current_color_scheme,
      steps: steps.map((step) => Step.parse(owner, step)),
    });
  }

  @attr start;
  @attr completed;
  @attr steps;
  @attr currentColorScheme;

  get totalSteps() {
    return this.steps.length;
  }

  get title() {
    return this.findStep("forum-tile")?.valueFor("title");
  }

  get logoUrl() {
    return this.findStep("logos")?.valueFor("logo");
  }

  get currentColors() {
    const step = this.findStep("styling");

    if (!step) {
      return this.currentColorScheme;
    }

    const field = step.findField("color_scheme");

    return field?.chosen?.data.colors;
  }

  get font() {
    return this.findStep("styling")?.findField("body_font").chosen;
  }

  get headingFont() {
    return this.findStep("styling")?.findField("heading_font").chosen;
  }

  findStep(id) {
    return this.steps.find((step) => step.id === id);
  }
}

const ValidStates = {
  UNCHECKED: 0,
  INVALID: 1,
  VALID: 2,
};

export class Step extends DObject {
  static parse(owner, { fields, ...payload }) {
    return new Step(owner, {
      ...payload,
      fields: fields.map((field) => Field.parse(owner, field)),
    });
  }

  @attr id;
  @attr next;
  @attr previous;
  @attr description;
  @attr title;
  @attr index;
  @attr banner;
  @attr emoji;
  @attr fields;

  @tracked _validState = ValidStates.UNCHECKED;

  get valid() {
    return this._validState === ValidStates.VALID;
  }

  set valid(valid) {
    this._validState = valid ? ValidStates.VALID : ValidStates.INVALID;
  }

  get invalid() {
    return this._validState === ValidStates.INVALID;
  }

  get unchecked() {
    return this._validState === ValidStates.UNCHECKED;
  }

  get displayIndex() {
    return this.index + 1;
  }

  valueFor(id) {
    return this.findField(id)?.value;
  }

  findField(id) {
    return this.fields.find((field) => field.id === id);
  }

  fieldError(id, description) {
    let field = this.findField(id);
    if (field) {
      field.errorDescription = description;
    }
  }

  validate() {
    let valid = this.fields
      .map((field) => field.validate())
      .every((result) => result);

    return (this.valid = valid);
  }

  serialize() {
    let data = {};

    for (let field of this.fields) {
      data[field.id] = field.value;
    }

    return data;
  }

  async save() {
    try {
      return await ajax({
        url: `/wizard/steps/${this.id}`,
        type: "PUT",
        data: { fields: this.serialize() },
      });
    } catch (error) {
      for (let err of error.jqXHR.responseJSON.errors) {
        this.fieldError(err.field, err.description);
      }
    }
  }
}

export class Field extends DObject {
  static parse(
    owner,
    { extra_description, show_in_sidebar, choices, ...payload }
  ) {
    return new Field(owner, {
      ...payload,
      extraDescription: extra_description,
      showInSidebar: show_in_sidebar,
      choices: choices?.map((choice) => Choice.parse(owner, choice)),
    });
  }

  @attr id;
  @attr type;
  @attr required;
  @attr label;
  @attr placeholder;
  @attr description;
  @attr extraDescription;
  @attr icon;
  @attr disabled;
  @attr showInSidebar;
  @attr choices;

  @tracked _value = null;
  @tracked _validState = ValidStates.UNCHECKED;
  @tracked _errorDescription = null;

  _listeners = [];

  get value() {
    return this._value;
  }

  @attr
  set value(newValue) {
    this._value = newValue;

    for (let listener of this._listeners) {
      listener();
    }
  }

  get chosen() {
    return this.choices?.find((choice) => choice.id === this.value);
  }

  get valid() {
    return this._validState === ValidStates.VALID;
  }

  set valid(valid) {
    this._validState = valid ? ValidStates.VALID : ValidStates.INVALID;
    this._errorDescription = null;
  }

  get invalid() {
    return this._validState === ValidStates.INVALID;
  }

  get unchecked() {
    return this._validState === ValidStates.UNCHECKED;
  }

  get errorDescription() {
    return this._errorDescription;
  }

  set errorDescription(description) {
    this._validState = ValidStates.INVALID;
    this._errorDescription = description;
  }

  validate() {
    let valid = true;

    if (this.required) {
      valid = !!(this.value?.length > 0);
    }

    return (this.valid = valid);
  }

  addListener(listener) {
    this._listeners.push(listener);
  }

  removeListener(listener) {
    this._listeners = this._listeners.filter((l) => l === listener);
  }
}

export class Choice extends DObject {
  static parse(owner, { extra_label, ...payload }) {
    return new Choice(owner, { ...payload, extraLabel: extra_label });
  }

  @attr id;
  @attr label;
  @attr extraLabel;
  @attr description;
  @attr icon;
  @attr data;
}
