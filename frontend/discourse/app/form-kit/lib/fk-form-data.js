/**
 * A Changeset class that manages data and tracks changes.
 */
import { tracked } from "@glimmer/tracking";
import { next } from "@ember/runloop";
import { applyPatches, enablePatches, produce } from "immer";

enablePatches();

export default class FKFormData {
  /**
   * The original data.
   * @type {any}
   */
  @tracked data;

  /**
   * The draft data, stores the changes made to original data, without mutating original data.
   * @type {any}
   */
  @tracked draftData;

  /**
   * The errors associated with the changeset.
   * @type {Object}
   */
  @tracked errors = {};

  /**
   * The patches to be applied.
   * @type {Array}
   */
  patches = [];

  /**
   * The inverse patches to be applied, useful for rollback.
   * @type {Array}
   */
  inversePatches = [];

  /**
   * Creates an instance of Changeset.
   * @param {any} data - The initial data.
   */
  constructor(data) {
    try {
      this.data = produce(data, () => {});
      this.draftData = produce(data, () => {});
    } catch (e) {
      if (e.message.includes("[Immer]")) {
        throw new Error("[FormKit]: the @data property expects a POJO.");
      }
    }
  }

  /**
   * Checks if the changeset is valid.
   * @return {boolean} True if there are no errors.
   */
  get isValid() {
    return Object.keys(this.errors).length === 0;
  }

  /**
   * Checks if the changeset is invalid.
   * @return {boolean} True if there are errors.
   */
  get isInvalid() {
    return !this.isValid;
  }

  /**
   * Checks if the changeset is pristine.
   * @return {boolean} True if no patches have been applied.
   */
  get isPristine() {
    return this.patches.length + this.inversePatches.length === 0;
  }

  /**
   * Checks if the changeset is dirty.
   * @return {boolean} True if patches have been applied.
   */
  get isDirty() {
    return !this.isPristine;
  }

  /**
   * Executes the patches to update the data.
   */
  execute() {
    this.data = applyPatches(this.data, this.patches);
  }

  /**
   * Reverts the patches to update the data.
   */
  unexecute() {
    this.data = applyPatches(this.data, this.inversePatches);
  }

  /**
   * Saves the changes by executing the patches and resetting them.
   */
  save() {
    this.execute();
    this.resetPatches();
  }

  /**
   * Rolls back all changes by applying the inverse patches.
   * @return {Promise<void>} A promise that resolves after the rollback is complete.
   */
  async rollback() {
    while (this.inversePatches.length > 0) {
      this.draftData = applyPatches(this.draftData, [
        this.inversePatches.pop(),
      ]);
    }

    this.resetPatches();

    await new Promise((resolve) => next(resolve));
  }

  /**
   * Adds an error to a specific property.
   * @param {string} name - The property name.
   * @param {Object} error - The error to add.
   * @param {string} error.title - The title of the error.
   * @param {string} error.message - The message of the error.
   */
  addError(name, error) {
    if (this.errors.hasOwnProperty(name)) {
      this.errors[name].messages.push(error.message);
      this.errors = { ...this.errors };
    } else {
      this.errors = {
        ...this.errors,
        [name]: {
          title: error.title,
          messages: [error.message],
        },
      };
    }
  }

  /**
   * Removes an error from a specific property.
   * @param {string} name - The property name.
   */
  removeError(name) {
    delete this.errors[name];
    this.errors = { ...this.errors };
  }

  /**
   * Removes all errors from the changeset.
   */
  removeErrors() {
    this.errors = {};
  }

  /**
   * Gets the value of a specific property from the draft data.
   * @param {string} name - The property name.
   * @return {any} The value of the property.
   */
  get(name) {
    const parts = name.split(".");
    let target = this.draftData[parts.shift()];
    while (parts.length) {
      target = target[parts.shift()];
    }
    return target;
  }

  /**
   * Sets the value of a specific property in the draft data and tracks the changes.
   * @param {string} name - The property name.
   * @param {any} value - The value to set.
   */
  set(name, value) {
    this.draftData = produce(
      this.draftData,
      (target) => {
        const parts = name.split(".");
        while (parts.length > 1) {
          target = target[parts.shift()];
        }
        target[parts[0]] = value;
      },
      (patches, inversePatches) => {
        this.patches.push(...patches);
        this.inversePatches.push(...inversePatches);
      }
    );
  }

  /**
   * Resets the patches and inverse patches.
   */
  resetPatches() {
    this.patches = [];
    this.inversePatches = [];
  }
}
