import Mixin from "@ember/object/mixin";
import { get } from "@ember/object";

export default Mixin.create({
  isValidInput(eventKey) {
    // relying on passing the event to the input is risky as it could not work
    // dispatching the event won't work as the event won't be trusted
    // safest solution is to filter event and prefill filter with it
    const nonInputKeysRegex =
      /F\d+|Arrow.+|Meta|Alt|Control|Shift|Delete|Enter|Escape|Tab|Space|Insert|Backspace/;
    return !nonInputKeysRegex.test(eventKey);
  },

  defaultItem(value, name) {
    if (this.selectKit.valueProperty) {
      const item = {};
      item[this.selectKit.valueProperty] = value;
      item[this.selectKit.nameProperty] = name;
      return item;
    } else {
      return name || value;
    }
  },

  itemForValue(value, content) {
    if (this.selectKit.valueProperty) {
      return content.findBy(this.selectKit.valueProperty, value);
    } else {
      return value;
    }
  },

  getProperty(item, property, options = { definedOnly: true }) {
    const { definedOnly } = options;

    if (item && typeof property === "string") {
      const attempt = get(item, property);
      if (attempt) {
        return attempt;
      }
    }

    property = get(this.selectKit, property);

    if (!item) {
      return null;
    }

    if (!property && definedOnly) {
      return null;
    } else if (!property) {
      return item;
    } else if (typeof property === "string") {
      return get(item, property);
    } else {
      return property(item);
    }
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
      if (content.includes(item)) {
        return item;
      }
    } else if (typeof property === "string") {
      return content.findBy(property, this[getter](item));
    } else {
      const name = this[getter](item);
      return content.find((contentItem) => {
        return this[getter](contentItem) === name;
      });
    }
  },

  _isNumeric(input) {
    return !isNaN(parseFloat(input)) && isFinite(input);
  },

  _normalize(input) {
    if (input) {
      input = input.toLowerCase();

      if (typeof input.normalize === "function") {
        input = input.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
      }
    }

    return input;
  },
});
