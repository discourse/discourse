import { get } from "@ember/object";
import Mixin from "@ember/object/mixin";

export default Mixin.create({
  defaultItem(value, name) {
    if (this.selectKit.valueProperty) {
      return {
        [this.selectKit.valueProperty]: value,
        [this.selectKit.nameProperty]: name,
      };
    }
    return name || value;
  },

  itemForValue(value, content) {
    if (this.selectKit.valueProperty) {
      return content.findBy(this.selectKit.valueProperty, value);
    }
    return value;
  },

  getProperty(item, property, options = { definedOnly: true }) {
    if (!item) {
      return null;
    }

    if (item && typeof property === "string") {
      const attempt = get(item, property);
      if (attempt) {
        return attempt;
      }
    }

    property = get(this.selectKit, property);
    if (!property) {
      return options.definedOnly ? null : item;
    }
    if (typeof property === "string") {
      return get(item, property);
    }
    return property(item);
  },

  getValue(item) {
    return this.getProperty(item, "valueProperty", { definedOnly: false });
  },

  getName(item) {
    return this.getProperty(item, "nameProperty", { definedOnly: false });
  },

  findValue(content, item) {
    return this._findInContent(content, item, "valueProperty", "getValue");
  },

  findName(content, item) {
    return this._findInContent(content, item, "nameProperty", "getName");
  },

  _findInContent(content, item, type, getter) {
    const property = get(this.selectKit, type);
    if (!property) {
      return content.includes(item) ? item : undefined;
    }

    if (typeof property === "string") {
      return content.findBy(property, this[getter](item));
    }

    const name = this[getter](item);
    return content.find((contentItem) => {
      return this[getter](contentItem) === name;
    });
  },
});
