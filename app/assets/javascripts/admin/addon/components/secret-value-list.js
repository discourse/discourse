import Component from "@ember/component";
import { action, set } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { classNameBindings } from "@ember-decorators/component";
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
}
