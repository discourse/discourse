import { on } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNameBindings: [":value-list", ":secret-value-list"],
  inputDelimiter: null,
  collection: null,
  values: null,
  validationMessage: null,

  @on("didReceiveAttrs")
  _setupCollection() {
    const values = this.get("values");

    this.set(
      "collection",
      this._splitValues(values, this.get("inputDelimiter") || "\n")
    );
  },

  actions: {
    changeKey(index, newValue) {
      if (this._checkInvalidInput(newValue)) return;
      this._replaceValue(index, newValue, "key");
    },

    changeSecret(index, newValue) {
      if (this._checkInvalidInput(newValue)) return;
      this._replaceValue(index, newValue, "secret");
    },

    addValue() {
      if (this._checkInvalidInput([this.get("newKey"), this.get("newSecret")]))
        return;
      this._addValue(this.get("newKey"), this.get("newSecret"));
      this.setProperties({ newKey: "", newSecret: "" });
    },

    removeValue(value) {
      this._removeValue(value);
    }
  },

  _checkInvalidInput(inputs) {
    this.set("validationMessage", null);
    for (let input of inputs) {
      if (Ember.isEmpty(input) || input.includes("|")) {
        this.set(
          "validationMessage",
          I18n.t("admin.site_settings.secret_list.invalid_input")
        );
        return true;
      }
    }
  },

  _addValue(value, secret) {
    this.get("collection").addObject({ key: value, secret: secret });
    this._saveValues();
  },

  _removeValue(value) {
    const collection = this.get("collection");
    collection.removeObject(value);
    this._saveValues();
  },

  _replaceValue(index, newValue, keyName) {
    let item = this.get("collection")[index];
    Ember.set(item, keyName, newValue);

    this._saveValues();
  },

  _saveValues() {
    this.set(
      "values",
      this.get("collection")
        .map(function(elem) {
          return `${elem.key}|${elem.secret}`;
        })
        .join("\n")
    );
  },

  _splitValues(values, delimiter) {
    if (values && values.length) {
      const keys = ["key", "secret"];
      var res = [];
      values.split(delimiter).forEach(function(str) {
        var object = {};
        str.split("|").forEach(function(a, i) {
          object[keys[i]] = a;
        });
        res.push(object);
      });

      return res;
    } else {
      return [];
    }
  }
});
