import Component from "@ember/component";
import I18n from "I18n";
import { isEmpty } from "@ember/utils";
import { on } from "discourse-common/utils/decorators";
import { emojiUrlFor } from "discourse/lib/text";
import { action, set } from "@ember/object";
import { later, schedule } from "@ember/runloop";

export default Component.extend({
  classNameBindings: [":value-list"],
  collection: null,
  values: null,
  validationMessage: null,
  emojiPickerIsActive: false,
  isEditorFocused: false,
  emojiName: null,

  init() {
    this._super(...arguments);
    this.set("collection", []);
  },

  @action
  emojiSelected(code) {
    this.set("emojiName", code);
    this.set("emojiPickerIsActive", !this.emojiPickerIsActive);
    this.set("isEditorFocused", !this.isEditorFocused);
  },

  @action
  openEmojiPicker() {
    this.set("isEditorFocused", !this.isEditorFocused);
    later(() => {
      this.set("emojiPickerIsActive", !this.emojiPickerIsActive);
    }, 100);
  },

  @action
  clearInput() {
    this.set("emojiName", "");
  },

  @on("didReceiveAttrs")
  _setupCollection() {
    this.set("collection", this._splitValues(this.values));
  },

  _splitValues(values) {
    if (values && values.length) {
      const res = [];
      const emojis = values.split("|");
      emojis.forEach((emoji, index) => {
        const object = {};
        object.value = emoji;

        object.emojiUrl = emojiUrlFor(emoji);
        object.isEditable = true;

        object.isEditing = false;

        object.isLast = emojis.length - 1 === index;

        res.push(object);
      });

      return res;
    } else {
      return [];
    }
  },

  @action
  editValue(index) {
    const item = this.collection[index];
    if (item.isEditable) {
      set(item, "isEditing", !item.isEditing);
      schedule("afterRender", () => {
        const textbox = document.querySelector(
          `[data-index="${index}"] .value-input`
        );
        if (textbox) {
          textbox.focus();
        }
      });
    }
  },

  @action
  changeValue(index, newValue) {
    const item = this.collection[index];

    if (this._checkInvalidInput(newValue)) {
      const oldValues = this.values.split("|");

      set(item, "value", oldValues[index - 1]);
      set(item, "isEditing", !item.isEditing);

      return;
    }

    this._replaceValue(index, newValue);

    set(item, "isEditing", !item.isEditing);
  },

  @action
  addValue() {
    if (this._checkInvalidInput([this.emojiName])) {
      return;
    }
    this._addValue(this.emojiName);
    this.set("emojiName", "");
  },

  @action
  removeValue(value) {
    this._removeValue(value);
  },

  @action
  shiftUp(index) {
    if (!index) {
      return;
    }
    const temp = this.collection[index];
    this.collection[index] = this.collection[index - 1];
    this.collection[index - 1] = temp;
    this._saveValues();
  },

  @action
  shiftDown(index) {
    if (index === this.collection.length) {
      return;
    }
    const temp = this.collection[index];
    this.collection[index] = this.collection[index + 1];
    this.collection[index + 1] = temp;
    this._saveValues();
  },

  _checkInvalidInput(input) {
    this.set("validationMessage", null);

    if (isEmpty(input) || input.includes("|") || !emojiUrlFor(input)) {
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
      value: value,
      emojiUrl: emojiUrlFor(value),
      isLast: true,
      isEditable: true,
      isEditing: false,
    };
    this.collection.addObject(object);
    this._saveValues();
  },

  _removeValue(value) {
    const collection = this.collection;
    collection.removeObject(value);
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
