import discourseComputed, { on } from "discourse-common/utils/decorators";
import { empty, reads } from "@ember/object/computed";
import Component from "@ember/component";
import { makeArray } from "discourse-common/lib/helpers";

export default Component.extend({
  classNameBindings: [":value-list"],
  inputInvalid: empty("newValue"),
  inputDelimiter: null,
  inputType: null,
  newValue: "",
  collection: null,
  values: null,
  noneKey: reads("addKey"),

  @on("didReceiveAttrs")
  _setupCollection() {
    const values = this.values;
    if (this.inputType === "array") {
      this.set("collection", values || []);
      return;
    }

    this.set(
      "collection",
      this._splitValues(values, this.inputDelimiter || "\n")
    );
  },

  @discourseComputed("choices.[]", "collection.[]")
  filteredChoices(choices, collection) {
    return makeArray(choices).filter((i) => collection.indexOf(i) < 0);
  },

  keyDown(event) {
    if (event.key === "Enter") {
      this.send("addValue", this.newValue);
    }
  },

  actions: {
    changeValue(index, newValue) {
      this._replaceValue(index, newValue);
    },

    addValue(newValue) {
      if (this.inputInvalid) {
        return;
      }

      this.set("newValue", null);
      this._addValue(newValue);
    },

    removeValue(value) {
      this._removeValue(value);
    },

    selectChoice(choice) {
      this._addValue(choice);
    },

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

      this._saveValues();
    },
  },

  _addValue(value) {
    this.collection.addObject(value);

    if (this.choices) {
      this.set("choices", this.choices.rejectBy("id", value));
    } else {
      this.set("choices", []);
    }

    this._saveValues();
  },

  _removeValue(value) {
    this.collection.removeObject(value);

    if (this.choices) {
      this.set("choices", this.choices.concat([value]).uniq());
    } else {
      this.set("choices", makeArray(value));
    }

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

  @discourseComputed("collection")
  showUpDownButtons(collection) {
    return collection.length - 1 ? true : false;
  },

  _splitValues(values, delimiter) {
    if (values && values.length) {
      return values.split(delimiter).filter((x) => x);
    } else {
      return [];
    }
  },
});
