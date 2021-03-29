import Component from "@ember/component";
import I18n from "I18n";
import { on } from "discourse-common/utils/decorators";
import { emojiUrlFor } from "discourse/lib/text";
import { action, set, setProperties } from "@ember/object";
import { later, schedule } from "@ember/runloop";

export default Component.extend({
  classNameBindings: [":value-list", ":emoji-list"],
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
  closeEmojiPicker() {
    this.collection.forEach((item) => {
      if (item.isEditing) {
        set(item, "isEditing", false);
      }
    });

    this.set("emojiPickerIsActive", false);
    this.set("isEditorFocused", false);
  },

  @action
  emojiSelected(code) {
    if (!this._validateInput(code)) {
      return;
    }

    const item = this.collection.findBy("isEditing");
    if (item) {
      setProperties(item, {
        value: code,
        emojiUrl: emojiUrlFor(code),
        isEditing: false,
      });

      this._saveValues();
    } else {
      this.set("emojiName", code);
    }

    this.set("emojiPickerIsActive", false);
    this.set("isEditorFocused", false);
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
          showUpDownButtons: emojis.length - 1 ? true : false,
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
    this.closeEmojiPicker();
    schedule("afterRender", () => {
      if (parseInt(index, 10) >= 0) {
        const item = this.collection[index];
        if (item.isEditable) {
          set(item, "isEditing", true);
        }
      }

      this.set("isEditorFocused", true);
      later(() => {
        if (!this.isDestroyed) {
          this.set("emojiPickerIsActive", true);
        }
      }, 100);
    });
  },

  @action
  addValue() {
    this._addValue(this.emojiName);
    this.set("emojiName", null);
  },

  @action
  removeValue(value) {
    this._removeValue(value);
  },

  rotateCollection(direction) {
    if (direction < 0) {
      this.collection.push(this.collection.shift());
    } else {
      this.collection.unshift(this.collection.pop());
    }

    this._saveValues();
  },

  @action
  shift(operation, index) {
    if (!operation) {
      return;
    }

    // rotate if shift is up and index is 0
    if (!index && operation < 0) {
      return this.rotateCollection(-1);
    }

    // rotate if shift is down and index is last
    if (index === this.collection.length - 1 && operation > 0) {
      return this.rotateCollection(1);
    }

    const nextIndex = index + operation;
    const collectionValue = this.collection[index];
    this.collection[index] = this.collection[nextIndex];
    this.collection[nextIndex] = collectionValue;
    this._saveValues();
  },

  _validateInput(input) {
    this.set("validationMessage", null);

    if (!emojiUrlFor(input)) {
      this.set(
        "validationMessage",
        I18n.t("admin.site_settings.emoji_list.invalid_input")
      );
      return false;
    }

    return true;
  },

  _addValue(value) {
    const newCollectionValue = {
      value,
      emojiUrl: emojiUrlFor(value),
      isEditable: true,
      isEditing: false,
      showUpDownButtons: this.collection.length - 1 ? true : false,
    };
    this.collection.addObject(newCollectionValue);
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
