import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import { addUniqueValueToArray } from "discourse/lib/array-tools";
import { i18n } from "discourse-i18n";

const INPUT_DELIMITER = "\n";

export default class SecretValueList extends Component {
  @tracked newKey;
  @tracked newSecret;

  @cached
  get collection() {
    return this.#splitValues(this.args.values, INPUT_DELIMITER);
  }

  @action
  changeKey(index, event) {
    const newValue = event.target.value;

    if (this.#checkInvalidInput(newValue)) {
      return;
    }

    this.#replaceValue(index, newValue, "key");
  }

  @action
  changeSecret(index, event) {
    const newValue = event.target.value;

    if (this.#checkInvalidInput(newValue)) {
      return;
    }

    this.#replaceValue(index, newValue, "secret");
  }

  @action
  addValue() {
    if (this.#checkInvalidInput([this.newKey, this.newSecret])) {
      return;
    }
    this.#addValue(this.newKey, this.newSecret);

    this.newKey = "";
    this.newSecret = "";
  }

  @action
  removeValue(value) {
    this.#removeValue(value);
  }

  #checkInvalidInput(inputs) {
    for (const input of inputs) {
      if (isEmpty(input) || input.includes("|")) {
        this.args.setValidationMessage(
          i18n("admin.site_settings.secret_list.invalid_input")
        );
        return true;
      }
    }

    if (this.collection.some((item) => item.key.trim() === inputs[0].trim())) {
      this.args.setValidationMessage(
        i18n("admin.site_settings.secret_list.already_exists", {
          key: inputs[0],
        })
      );
      return true;
    }

    this.args.setValidationMessage(null);
  }

  #addValue(value, secret) {
    const updatedCollection = addUniqueValueToArray(
      [...this.collection],
      {
        key: value,
        secret,
      },
      (item) => item.key
    );
    this.#saveValues(updatedCollection);
  }

  #removeValue(value) {
    const updatedCollection = [...this.collection].filter(
      (item) => !(item.key === value.key && item.secret === value.secret)
    );
    this.#saveValues(updatedCollection);
  }

  #replaceValue(index, newValue, keyName) {
    const updatedCollection = [...this.collection];

    const item = updatedCollection[index];
    set(item, keyName, newValue);

    this.#saveValues(updatedCollection);
  }

  #saveValues(updatedCollection) {
    this.args.changeValueCallback(
      updatedCollection
        .map(function (elem) {
          return `${elem.key}|${elem.secret}`;
        })
        .join(INPUT_DELIMITER)
    );
  }

  #splitValues(values, delimiter) {
    if (values && values.length) {
      const keys = ["key", "secret"];
      const res = [];
      values.split(delimiter).forEach(function (str) {
        const object = {};
        str.split("|").forEach(function (a, i) {
          object[keys[i]] = a;
        });
        res.push(object);
      });

      return res;
    } else {
      return [];
    }
  }

  <template>
    <div class="value-list secret-value-list">
      {{#if this.collection}}
        <div class="values">
          {{#each this.collection as |value index|}}
            <div class="value" data-index={{index}}>
              <DButton
                @action={{fn this.removeValue value}}
                @icon="xmark"
                class="btn-default remove-value-btn btn-small"
              />
              <Input
                @value={{value.key}}
                class="value-input"
                {{on "focusout" (fn this.changeKey index)}}
              />
              <Input
                @value={{value.secret}}
                class="value-input"
                @type={{if @isSecret "password" "text"}}
                {{on "focusout" (fn this.changeSecret index)}}
              />
            </div>
          {{/each}}
        </div>
      {{/if}}

      <div class="value">
        <TextField
          @value={{this.newKey}}
          @placeholder={{this.setting.placeholder.key}}
          class="new-value-input key"
        />
        <Input
          @type={{if @isSecret "password" "text"}}
          @value={{this.newSecret}}
          class="new-value-input secret"
          placeholder={{this.setting.placeholder.value}}
        />
        <DButton
          @action={{this.addValue}}
          @icon="plus"
          class="add-value-btn btn-small"
        />
      </div>
    </div>
  </template>
}
