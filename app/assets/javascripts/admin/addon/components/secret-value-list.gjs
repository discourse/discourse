import Component, { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, set } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { classNameBindings } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import { i18n } from "discourse-i18n";

@classNameBindings(":value-list", ":secret-value-list")
export default class SecretValueList extends Component {
  inputDelimiter = null;
  collection = null;
  values = null;

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    this.set(
      "collection",
      this._splitValues(this.values, this.inputDelimiter || "\n")
    );
  }

  @action
  changeKey(index, event) {
    const newValue = event.target.value;

    if (this._checkInvalidInput(newValue)) {
      return;
    }

    this._replaceValue(index, newValue, "key");
  }

  @action
  changeSecret(index, event) {
    const newValue = event.target.value;

    if (this._checkInvalidInput(newValue)) {
      return;
    }

    this._replaceValue(index, newValue, "secret");
  }

  @action
  addValue() {
    if (this._checkInvalidInput([this.newKey, this.newSecret])) {
      return;
    }
    this._addValue(this.newKey, this.newSecret);
    this.setProperties({ newKey: "", newSecret: "" });
  }

  @action
  removeValue(value) {
    this._removeValue(value);
  }

  _checkInvalidInput(inputs) {
    for (let input of inputs) {
      if (isEmpty(input) || input.includes("|")) {
        this.setValidationMessage(
          i18n("admin.site_settings.secret_list.invalid_input")
        );
        return true;
      }
    }
    this.setValidationMessage(null);
  }

  _addValue(value, secret) {
    this.collection.addObject({ key: value, secret });
    this._saveValues();
  }

  _removeValue(value) {
    const collection = this.collection;
    collection.removeObject(value);
    this._saveValues();
  }

  _replaceValue(index, newValue, keyName) {
    let item = this.collection[index];
    set(item, keyName, newValue);

    this._saveValues();
  }

  _saveValues() {
    this.set(
      "values",
      this.collection
        .map(function (elem) {
          return `${elem.key}|${elem.secret}`;
        })
        .join("\n")
    );
  }

  _splitValues(values, delimiter) {
    if (values && values.length) {
      const keys = ["key", "secret"];
      let res = [];
      values.split(delimiter).forEach(function (str) {
        let object = {};
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
              @type={{if this.isSecret "password" "text"}}
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
        @type="password"
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
  </template>
}
