import { empty } from "@ember/object/computed";
import Component from "@ember/component";
import { action } from "@ember/object";
import { on } from "discourse-common/utils/decorators";

export default Component.extend({
  classNameBindings: [":simple-list", ":value-list"],
  inputEmpty: empty("newValue"),
  inputDelimiter: null,
  inputType: null,
  newValue: "",
  collection: null,
  values: null,

  @on("didReceiveAttrs")
  _setupCollection() {
    if (this.inputType === "array") {
      this.set("collection", this.values || []);
      return;
    }

    this.set(
      "collection",
      this._splitValues(this.values, this.inputDelimiter || "\n")
    );
  },

  keyDown(event) {
    if (event.keyCode === 13) this.addValue(this.newValue);
  },

  @action
  changeValue(index, newValue) {
    this._replaceValue(index, newValue);
  },

  @action
  addValue(newValue) {
    if (this.inputInvalid) return;

    this.set("newValue", null);
    this._addValue(newValue);
  },

  @action
  removeValue(value) {
    this._removeValue(value);
  },

  _addValue(value) {
    this.collection.addObject(value);
    this._saveValues();
  },

  _removeValue(value) {
    this.collection.removeObject(value);
    this._saveValues();
  },

  _replaceValue(index, newValue) {
    this.collection.replace(index, 1, [newValue]);
    this._saveValues();
  },

  _saveValues() {
    if (this.inputType === "array") {
      this.set("values", this.collection);
      return;
    }

    this.set("values", this.collection.join(this.inputDelimiter || "\n"));
  },

  _splitValues(values, delimiter) {
    if (values && values.length) {
      return values.split(delimiter).filter(Boolean);
    } else {
      return [];
    }
  }
});
