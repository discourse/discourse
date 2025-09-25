/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set, setProperties } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { classNameBindings } from "@ember-decorators/component";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import EmojiPicker from "discourse/components/emoji-picker";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
import discourseComputed from "discourse/lib/decorators";
import { emojiUrlFor } from "discourse/lib/text";
import { i18n } from "discourse-i18n";

@classNameBindings(":value-list", ":emoji-list")
export default class EmojiValueList extends Component {
  @service menu;

  values = null;

  @discourseComputed("values")
  collection(values) {
    values = values || "";

    return values
      .split("|")
      .filter(Boolean)
      .map((value) => {
        return {
          isEditable: true,
          isEditing: false,
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

    const item = this.collection.find((emoji) => emoji.isEditing);
    if (item) {
      setProperties(item, {
        value: code,
        emojiUrl: emojiUrlFor(code),
        isEditing: false,
      });

      this._saveValues();
    } else {
      const newCollectionValue = {
        value: code,
        emojiUrl: emojiUrlFor(code),
        isEditable: true,
        isEditing: false,
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
        const emoji = {
          isEditable: true,
          isEditing: false,
        };
        emoji.value = emojiName;
        emoji.emojiUrl = emojiUrlFor(emojiName);

        emojiList.push(emoji);
      });

      return emojiList;
    } else {
      return [];
    }
  }

  @action
  editValue(index, event) {
    schedule("afterRender", () => {
      if (parseInt(index, 10) >= 0) {
        const item = this.collection[index];
        if (item.isEditable) {
          set(item, "isEditing", true);
        }
      }

      this.menu.show(event.target, {
        identifier: "emoji-picker",
        groupIdentifier: "emoji-picker",
        component: EmojiPickerDetached,
        modalForMobile: true,
        data: {
          context: "chat",
          didSelectEmoji: (emoji) => {
            this._replaceValue(index, emoji);
          },
        },
      });
    });
  }

  @action
  removeValue(value) {
    this._removeValue(value);
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

  _removeValue(value) {
    this.collection.removeObject(value);
    this._saveValues();
  }

  _replaceValue(index, newValue) {
    const item = this.collection[index];
    if (item.value === newValue) {
      return;
    }
    set(item, "value", newValue);
    this._saveValues();
  }

  _saveValues() {
    this.set("values", this.collection.mapBy("value").join("|"));
  }

  <template>
    {{#if this.collection}}
      <ul class="values emoji-value-list">
        {{#each this.collection as |data index|}}
          <li class="value" data-index={{index}}>
            <DButton
              @action={{fn this.removeValue data}}
              @icon="xmark"
              @disabled={{not data.isEditable}}
              class="btn-default remove-value-btn btn-small"
            />

            <div
              class="value-input emoji-details
                {{if data.isEditable 'can-edit'}}
                {{if data.isEditing 'd-editor-textarea-wrapper'}}"
              {{on "click" (fn this.editValue index)}}
              role="button"
            >
              <img
                height="15px"
                width="15px"
                src={{data.emojiUrl}}
                class="emoji-list-emoji"
              />
              <span class="emoji-name">{{data.value}}</span>
            </div>

            {{#if this.showUpDownButtons}}
              <DButton
                @action={{fn this.shift -1 index}}
                @icon="arrow-up"
                class="btn-default shift-up-value-btn btn-small"
              />
              <DButton
                @action={{fn this.shift 1 index}}
                @icon="arrow-down"
                class="btn-default shift-down-value-btn btn-small"
              />
            {{/if}}
          </li>
        {{/each}}
      </ul>
    {{/if}}

    <div class="value">
      <EmojiPicker
        @label={{i18n "admin.site_settings.emoji_list.add_emoji_button.label"}}
        @didSelectEmoji={{this.emojiSelected}}
      />
    </div>
  </template>
}
