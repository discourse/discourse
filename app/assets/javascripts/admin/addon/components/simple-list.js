import Component from "@ember/component";
import { action } from "@ember/object";
import { empty } from "@ember/object/computed";
import discourseComputed, { on } from "discourse-common/utils/decorators";

export default Component.extend({
  classNameBindings: [":simple-list", ":value-list"],
  inputEmpty: empty("newValue"),
  inputDelimiter: null,
  newValue: "",
  collection: null,
  values: null,

  @on("didReceiveAttrs")
  _setupCollection() {
    this.set("collection", this._splitValues(this.values, this.inputDelimiter));
  },

  keyDown(event) {
    if (event.which === 13) {
      this.addValue(this.newValue);
      return;
    }
  },

  @action
  changeValue(index, newValue) {
    this.collection.replace(index, 1, [newValue]);
    this.collection.arrayContentDidChange(index);
    this._onChange();
  },

  @action
  addValue(newValue) {
    if (this.inputEmpty) {
      return;
    }

    this.set("newValue", null);
    this.collection.addObject(newValue);
    this._onChange();
  },

  @action
  removeValue(value) {
    this.collection.removeObject(value);
    this._onChange();
  },

  @action
  shift(operation, index) {
    let futureIndex = index + operation;

    if (futureIndex > this.collection.length - 1) {
      futureIndex = 0;
    } else if (futureIndex < 0) {
      futureIndex = this.collection.length - 1;
    }

    const shiftedValue = this.collection[index];
    this.collection.removeAt(index);
    this.collection.insertAt(futureIndex, shiftedValue);

    this._onChange();
  },

  _onChange() {
    this.attrs.onChange && this.attrs.onChange(this.collection);
  },

  @discourseComputed("collection")
  showUpDownButtons(collection) {
    return collection.length - 1 ? true : false;
  },

  _splitValues(values, delimiter) {
    return values && values.length
      ? values.split(delimiter || "\n").filter(Boolean)
      : [];
  },
});
