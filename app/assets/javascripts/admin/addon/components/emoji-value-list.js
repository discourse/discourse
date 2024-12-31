import Component from "@ember/component";
import { action, setProperties } from "@ember/object";
import { classNameBindings } from "@ember-decorators/component";
import { emojiUrlFor } from "discourse/lib/text";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

@classNameBindings(":value-list", ":emoji-list")
export default class EmojiValueList extends Component {
  values = null;

  @discourseComputed("values")
  collection(values) {
    values = values || "";

    return values
      .split("|")
      .filter(Boolean)
      .map((value) => {
        return {
          value,
          emojiUrl: emojiUrlFor(value),
        };
      });
  }

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
      });

      this._saveValues();
    } else {
      const newCollectionValue = {
        value: code,
        emojiUrl: emojiUrlFor(code),
      };
      this.collection.addObject(newCollectionValue);
      this._saveValues();
    }
  }

  @discourseComputed("collection")
  showUpDownButtons(collection) {
    return collection.length - 1 ? true : false;
  }

  _splitValues(values) {
    if (values && values.length) {
      const emojiList = [];
      const emojis = values.split("|").filter(Boolean);
      emojis.forEach((emojiName) => {
        const emoji = { value: emojiName, emojiUrl: emojiUrlFor(emojiName) };
        emojiList.push(emoji);
      });

      return emojiList;
    } else {
      return [];
    }
  }

  @action
  removeValue(value) {
    this.collection.removeObject(value);
    this._saveValues();
  }

  @action
  shift(operation, index) {
    let futureIndex = index + operation;

    if (futureIndex > this.collection.length - 1) {
      futureIndex = 0;
    } else if (futureIndex < 0) {
      futureIndex = this.collection.length - 1;
    }

    const shiftedEmoji = this.collection[index];
    this.collection.removeAt(index);
    this.collection.insertAt(futureIndex, shiftedEmoji);

    this._saveValues();
  }

  _validateInput(input) {
    if (!emojiUrlFor(input)) {
      this.setValidationMessage(
        i18n("admin.site_settings.emoji_list.invalid_input")
      );
      return false;
    }

    this.setValidationMessage(null);
    return true;
  }

  _saveValues() {
    this.set("values", this.collection.mapBy("value").join("|"));
  }
}
