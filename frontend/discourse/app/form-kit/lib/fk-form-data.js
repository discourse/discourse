/**
 * A Changeset class that manages data and tracks changes.
 */
import { tracked } from "@glimmer/tracking";
import { trackedObject } from "@ember/reactive/collections";
import { next } from "@ember/runloop";
import { applyPatches, enablePatches, produce, setAutoFreeze } from "immer";

enablePatches();
setAutoFreeze(false);

export default class FKFormData {
  /**
   * The original data.
   * @type {any}
   */
  @tracked data;

  /**
   * The errors associated with the changeset.
   * @type {Object}
   */
  @tracked errors = {};

  /**
   * The patches to be applied.
   * @type {Array}
   */
  @tracked patches = [];

  /**
   * The inverse patches to be applied, useful for rollback.
   * @type {Array}
   */
  @tracked inversePatches = [];

  /**
   * The draft data yielded as transientData.
   * Uses trackedObject for per-property invalidation so that changing
   * one field does not re-render consumers of unrelated fields.
   * @type {any}
   */
  draftData;

  /**
   * Creates an instance of Changeset.
   * @param {any} data - The initial data.
   */
  constructor(data) {
    try {
      this.data = produce(data, () => {});
      this.draftData = trackedObject({ ...this.data });
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
    this.#applyPatches(this.inversePatches);
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
    while (parts.length && target != null) {
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
    const newPatches = [];
    const newInversePatches = [];

    produce(
      { ...this.draftData },
      (draft) => {
        const parts = name.split(".");
        let target = draft;
        while (parts.length > 1) {
          target = target[parts.shift()];
        }
        target[parts[0]] = value;
      },
      (patches, inversePatches) => {
        newPatches.push(...patches);
        newInversePatches.push(...inversePatches);
      }
    );

    this.patches = [...this.patches, ...newPatches];
    this.inversePatches = [...this.inversePatches, ...newInversePatches];
    this.#applyPatches(newPatches);
  }

  #applyPatches(patches) {
    for (const patch of patches) {
      const path = [...patch.path];
      const lastKey = path.pop();
      let target = this.draftData;

      // Structural changes (arrays/objects) at nested paths need new
      // references at every level so Glimmer's {{#each}} detects them.
      // Primitive changes are applied in-place to avoid re-renders.
      const cloneIntermediates =
        path.length > 0 &&
        (patch.op === "remove" ||
          (typeof patch.value === "object" && patch.value !== null));

      for (const key of path) {
        if (cloneIntermediates) {
          target[key] = Array.isArray(target[key])
            ? [...target[key]]
            : { ...target[key] };
        }
        target = target[key];
      }

      if (patch.op === "remove") {
        if (Array.isArray(target)) {
          target.splice(lastKey, 1);
        } else {
          delete target[lastKey];
        }
      } else {
        target[lastKey] = patch.value;
      }
    }
  }

  /**
   * Commits the current draft value of a specific field as the new baseline
   * and removes only its patches from the history. Other fields' dirty state
   * is unaffected.
   * @param {string} name - The top-level property name to commit.
   */
  commitField(name) {
    this.data = produce(this.data, (target) => {
      target[name] = this.draftData[name];
    });

    this.patches = this.patches.filter((p) => p.path[0] !== name);
    this.inversePatches = this.inversePatches.filter((p) => p.path[0] !== name);
  }

  /**
   * Resets the patches and inverse patches.
   */
  resetPatches() {
    this.patches = [];
    this.inversePatches = [];
  }
}
