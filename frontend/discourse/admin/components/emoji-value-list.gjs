import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set, setProperties } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import EmojiPicker from "discourse/components/emoji-picker";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
import { addUniqueValueToArray } from "discourse/lib/array-tools";
import { emojiUrlFor } from "discourse/lib/text";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class EmojiValueList extends Component {
  @service menu;

  get collection() {
    return this.args.values
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
    if (!this.#validateInput(code)) {
      return;
    }

    const newCollection = [...this.collection];
    const item = newCollection.find((emoji) => emoji.isEditing);

    if (item) {
      setProperties(item, {
        value: code,
        emojiUrl: emojiUrlFor(code),
        isEditing: false,
      });
    } else {
      const newCollectionValue = {
        value: code,
        emojiUrl: emojiUrlFor(code),
        isEditable: true,
        isEditing: false,
      };

      addUniqueValueToArray(newCollection, newCollectionValue);
    }

    this.#saveValues(newCollection);
  }

  get showUpDownButtons() {
    return this.collection.length > 1;
  }

  @action
  editValue(index, event) {
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
          this.#replaceValue(index, emoji);
        },
      },
    });
  }

  @action
  removeValue(item) {
    const newCollection = [...this.collection].filter(
      (emoji) => emoji.value !== item.value
    );
    this.#saveValues(newCollection);
  }

  @action
  shift(operation, index) {
    const updateCollection = [...this.collection];

    let futureIndex = index + operation;

    if (futureIndex > updateCollection.length - 1) {
      futureIndex = 0;
    } else if (futureIndex < 0) {
      futureIndex = updateCollection.length - 1;
    }

    const shiftedEmoji = updateCollection[index];
    updateCollection.splice(index, 1);
    updateCollection.splice(futureIndex, 0, shiftedEmoji);

    this.#saveValues(updateCollection);
  }

  #validateInput(input) {
    if (!emojiUrlFor(input)) {
      this.args.setValidationMessage(
        i18n("admin.site_settings.emoji_list.invalid_input")
      );
      return false;
    }

    this.args.setValidationMessage(null);
    return true;
  }

  #replaceValue(index, newValue) {
    const updateCollection = [...this.collection];

    const item = updateCollection[index];
    if (item.value === newValue) {
      return;
    }
    set(item, "value", newValue);

    this.#saveValues(updateCollection);
  }

  #saveValues(updateCollection) {
    this.args.changeValueCallback(
      updateCollection.map((item) => item.value).join("|")
    );
  }

  <template>
    <div class="value-list emoji-list">
      {{#if this.collection}}
        <ul class="values emoji-value-list">
          {{#each this.collection key="value" as |data index|}}
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
          @label={{i18n
            "admin.site_settings.emoji_list.add_emoji_button.label"
          }}
          @didSelectEmoji={{this.emojiSelected}}
        />
      </div>
    </div>
  </template>
}
