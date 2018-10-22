import { on } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNameBindings: [":value-list", ":secret-value-list"],
  inputInvalidKey: Ember.computed.empty("newKey"),
  inputInvalidSecret: Ember.computed.empty("newSecret"),
  inputDelimiter: null,
  collection: null,
  values: null,

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
      this._replaceValue(index, newValue, "key");
    },

    changeSecret(index, newValue) {
      this._replaceValue(index, newValue, "secret");
    },

    addValue() {
      if (this.get("inputInvalidKey") || this.get("inputInvalidSecret")) return;
      this._addValue(this.get("newKey"), this.get("newSecret"));
      this.setProperties({ newKey: "", newSecret: "" });
    },

    removeValue(value) {
      this._removeValue(value);
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
