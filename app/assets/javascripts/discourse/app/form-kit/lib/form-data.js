import { tracked } from "@glimmer/tracking";
import { get, set } from "@ember/object";
import { next } from "@ember/runloop";
import { applyPatches, enablePatches, produce } from "immer";

enablePatches();

export default class Changeset {
  @tracked data;

  @tracked draftData;

  @tracked innerErrors = {};

  patches = [];
  inversePatches = [];

  constructor(data) {
    this.data = produce(data, () => {});
    this.draftData = produce(data, () => {});
  }

  get isValid() {
    return Object.keys(this.errors).length === 0;
  }

  get isInvalid() {
    return !this.isValid;
  }

  get errors() {
    return this.innerErrors;
  }

  get isPristine() {
    return this.patches.length + this.inversePatches.length === 0;
  }

  get isDirty() {
    return !this.isPristine;
  }

  execute() {
    this.data = applyPatches(this.data, this.patches);
  }

  unexecute() {
    this.data = applyPatches(this.data, this.inversePatches);
  }

  save() {
    this.execute();
    this.resetPatches();
  }

  async rollback() {
    while (this.inversePatches.length > 0) {
      this.draftData = applyPatches(this.draftData, [
        this.inversePatches.pop(),
      ]);
    }

    await new Promise((resolve) => next(resolve));
  }

  rollbackProperty(property) {
    this.set(property, get(this.data, property));
  }

  addError(name, error) {
    if (this.innerErrors.hasOwnProperty(name)) {
      this.innerErrors[name].messages.push(error.message);
      this.innerErrors = { ...this.innerErrors };
    } else {
      this.innerErrors = {
        ...this.innerErrors,
        [name]: {
          title: error.title,
          messages: [error.message],
        },
      };
    }
  }

  removeError(name) {
    delete this.innerErrors[name];
    this.innerErrors = { ...this.innerErrors };
  }

  removeErrors() {
    this.innerErrors = {};
  }

  get(key) {
    return get(this.draftData, key);
  }

  set(key, value) {
    this.draftData = produce(
      this.draftData,
      (d) => {
        set(d, key, value);
      },
      (patches, inversePatches) => {
        this.patches.push(...patches);
        this.inversePatches.push(...inversePatches);
      }
    );
  }

  resetPatches() {
    this.patches = [];
    this.inversePatches = [];
  }
}
