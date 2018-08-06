import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNameBindings: [":value-list"],

  inputInvalid: Ember.computed.empty("newValue"),

  inputDelimiter: null,
  inputType: null,
  newValue: "",
  collection: null,
  values: null,
  noneKey: Ember.computed.alias("addKey"),

  @on("didReceiveAttrs")
  _setupCollection() {
    const values = this.get("values");
    if (this.get("inputType") === "array") {
      this.set("collection", values || []);
      return;
    }

    this.set(
      "collection",
      this._splitValues(values, this.get("inputDelimiter") || "\n")
    );
  },

  @computed("choices.[]", "collection.[]")
  filteredChoices(choices, collection) {
    return Ember.makeArray(choices).filter(i => collection.indexOf(i) < 0);
  },

  keyDown(event) {
    if (event.keyCode === 13) this.send("addValue", this.get("newValue"));
  },

  actions: {
    changeValue(index, newValue) {
      this._replaceValue(index, newValue);
    },

    addValue(newValue) {
      if (this.get("inputInvalid")) return;

      this.set("newValue", "");
      this._addValue(newValue);
    },

    removeValue(value) {
      this._removeValue(value);
    },

    selectChoice(choice) {
      this._addValue(choice);
    }
  },

  _addValue(value) {
    this.get("collection").addObject(value);
    this._saveValues();
  },

  _removeValue(value) {
    const collection = this.get("collection");
    collection.removeObject(value);
    this._saveValues();
  },

  _replaceValue(index, newValue) {
    this.get("collection").replace(index, 1, [newValue]);
    this._saveValues();
  },

  _saveValues() {
    if (this.get("inputType") === "array") {
      this.set("values", this.get("collection"));
      return;
    }

    this.set(
      "values",
      this.get("collection").join(this.get("inputDelimiter") || "\n")
    );
  },

  _splitValues(values, delimiter) {
    if (values && values.length) {
      return values.split(delimiter).filter(x => x);
    } else {
      return [];
    }
  }
});
