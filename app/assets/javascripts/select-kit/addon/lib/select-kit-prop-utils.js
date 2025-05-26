import { get } from "@ember/object";

export default function selectKitPropUtils(target) {
  target.prototype.defaultItem = function (value, name) {
    const { valueProperty, nameProperty } = this.selectKit;

    if (valueProperty) {
      return {
        [valueProperty]: value,
        [nameProperty]: name,
      };
    }
    return name || value;
  };

  target.prototype.itemForValue = function (value, content) {
    const { valueProperty } = this.selectKit;
    if (valueProperty) {
      return content.findBy(valueProperty, value);
    }
    return value;
  };

  target.prototype.getProperty = function (
    item,
    property,
    options = { definedOnly: true }
  ) {
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
  };

  target.prototype.getValue = function (item) {
    return this.getProperty(item, "valueProperty", { definedOnly: false });
  };

  target.prototype.getName = function (item) {
    return this.getProperty(item, "nameProperty", { definedOnly: false });
  };

  target.prototype.findValue = function (content, item) {
    return this._findInContent(content, item, "valueProperty", (i) =>
      this.getValue(i)
    );
  };

  target.prototype.findName = function (content, item) {
    return this._findInContent(content, item, "nameProperty", (i) =>
      this.getName(i)
    );
  };

  target.prototype._findInContent = function (content, item, type, getterFunc) {
    const property = get(this.selectKit, type);
    if (!property) {
      return content.includes(item) ? item : undefined;
    }

    if (typeof property === "string") {
      return content.findBy(property, getterFunc(item));
    }

    const name = getterFunc(item);
    return content.find((contentItem) => {
      return getterFunc(contentItem) === name;
    });
  };
}
