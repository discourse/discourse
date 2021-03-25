import Component from "@ember/component";
import I18n from "I18n";
import { on } from "discourse-common/utils/decorators";
import { emojiUrlFor } from "discourse/lib/text";
import { action, set, setProperties } from "@ember/object";
import { later } from "@ember/runloop";

export default Component.extend({
  classNameBindings: [":value-list"],
  collection: null,
  values: null,
  validationMessage: null,
  emojiPickerIsActive: false,
  isEditorFocused: false,
  emojiName: null,
  isEditingValue: false,

  init() {
    this._super(...arguments);
    this.set("collection", []);
  },

  @action
  emojiSelected(code) {
    const item = this.collection.findBy("isEditing");
    if (item) {
      setProperties(item, {
        value: code,
        emojiUrl: emojiUrlFor(code),
        isEditing: false,
      });

      this.set("isEditingValue", false);
      this._saveValues();
      return;
    }

    this.set("emojiName", code);
    this.set("emojiPickerIsActive", !this.emojiPickerIsActive);
    this.set("isEditorFocused", !this.isEditorFocused);
  },

  @action
  openEmojiPicker() {
    this.collection.forEach((item) => {
      set(item, "isEditing", false);
    });

    this.set("isEditorFocused", !this.isEditorFocused);
    later(() => {
      this.set("emojiPickerIsActive", !this.emojiPickerIsActive);
    }, 100);
  },

  @action
  clearInput() {
    this.set("emojiName", null);
  },

  @on("didReceiveAttrs")
  _setupCollection() {
    this.set("collection", this._splitValues(this.values));
  },

  _splitValues(values) {
    if (values && values.length) {
      const emojiList = [];
      const emojis = values.split("|").filter(Boolean);
      emojis.forEach((emojiName) => {
        const emoji = {
          isEditable: true,
          isEditing: false,
          length: emojis.length - 1,
        };
        emoji.value = emojiName;
        emoji.emojiUrl = emojiUrlFor(emojiName);

        emojiList.push(emoji);
      });

      return emojiList;
    } else {
      return [];
    }
  },

  @action
  editValue(index) {
    this.collection.forEach((item) => {
      set(item, "isEditing", false);
    });

    const item = this.collection[index];

    if (item.isEditable) {
      set(item, "isEditing", !item.isEditing);
      later(() => {
        this.set("isEditingValue", true);
      }, 100);
    }
  },

  @action
  addValue() {
    if (this._checkInvalidInput([this.emojiName])) {
      return;
    }
    this._addValue(this.emojiName);
    this.set("emojiName", null);
  },

  @action
  removeValue(value) {
    this._removeValue(value);
  },

  @action
  shiftUp(index) {
    if (!index) {
      this.arrayRotate(-1);
      return;
    }

    this.shift(index, -1);
  },

  arrayRotate(direction) {
    if (direction < 0) {
      this.collection.push(this.collection.shift());
    } else {
      this.collection.unshift(this.collection.pop());
    }

    this._saveValues();
  },

  shift(index, operation) {
    if (!operation) {
      return;
    }

    const nextIndex = index + operation;
    const temp = this.collection[index];
    this.collection[index] = this.collection[nextIndex];
    this.collection[nextIndex] = temp;
    this._saveValues();
  },

  @action
  shiftDown(index) {
    if (index === this.collection.length - 1) {
      this.arrayRotate(1);
      return;
    }

    this.shift(index, 1);
  },

  _checkInvalidInput(input) {
    this.set("validationMessage", null);

    if (!emojiUrlFor(input)) {
      this.set(
        "validationMessage",
        I18n.t("admin.site_settings.emoji_list.invalid_input")
      );
      return true;
    }

    return false;
  },

  _addValue(value) {
    const object = {
      value,
      emojiUrl: emojiUrlFor(value),
      isEditable: true,
      isEditing: false,
      length: this.collection.length - 1,
    };
    this.collection.addObject(object);
    this._saveValues();
  },

  _removeValue(value) {
    this.collection.removeObject(value);
    this._saveValues();
  },

  _replaceValue(index, newValue) {
    const item = this.collection[index];
    if (item.value === newValue) {
      return;
    }
    set(item, "value", newValue);
    this._saveValues();
  },

  _saveValues() {
    this.set("values", this.collection.mapBy("value").join("|"));
  },
});
