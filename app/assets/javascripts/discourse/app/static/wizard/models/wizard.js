import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

export default class Wizard {
  static async load() {
    return Wizard.parse((await ajax({ url: "/wizard.json" })).wizard);
  }

  static parse({ current_color_scheme, steps, ...payload }) {
    return new Wizard({
      ...payload,
      currentColorScheme: current_color_scheme,
      steps: steps.map((step) => Step.parse(step)),
    });
  }

  constructor(payload) {
    safeAssign(this, payload, [
      "start",
      "completed",
      "steps",
      "currentColorScheme",
    ]);
  }

  get totalSteps() {
    // We used to use this.steps.length() here, but we don't want to
    // include optional steps after "Ready" here.
    return 4;
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

export class Step {
  static parse({ fields, ...payload }) {
    return new Step({
      ...payload,
      fields: fields.map((field) => Field.parse(field)),
    });
  }

  @tracked _validState = ValidStates.UNCHECKED;

  constructor(payload) {
    safeAssign(this, payload, [
      "id",
      "next",
      "previous",
      "description",
      "title",
      "index",
      "banner",
      "emoji",
      "fields",
    ]);
  }

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

export class Field {
  static parse({ extra_description, show_in_sidebar, choices, ...payload }) {
    return new Field({
      ...payload,
      extraDescription: extra_description,
      showInSidebar: show_in_sidebar,
      choices: choices?.map((choice) => Choice.parse(choice)),
    });
  }

  @tracked _value = null;
  @tracked _validState = ValidStates.UNCHECKED;
  @tracked _errorDescription = null;

  _listeners = [];

  constructor(payload) {
    safeAssign(this, payload, [
      "id",
      "type",
      "required",
      "value",
      "label",
      "placeholder",
      "description",
      "extraDescription",
      "icon",
      "disabled",
      "showInSidebar",
      "choices",
    ]);
  }

  get value() {
    return this._value;
  }

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

export class Choice {
  static parse({ extra_label, ...payload }) {
    return new Choice({ ...payload, extraLabel: extra_label });
  }

  constructor({ id, label, extraLabel, description, icon, data }) {
    Object.assign(this, { id, label, extraLabel, description, icon, data });
  }
}

function safeAssign(object, payload, permittedKeys) {
  for (const [key, value] of Object.entries(payload)) {
    if (permittedKeys.includes(key)) {
      object[key] = value;
    }
  }
}
