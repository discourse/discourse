const { get, isNone } = Ember;

export default Ember.Mixin.create({
  _nameForContent(content) {
    if (isNone(content)) {
      return null;
    }

    if (typeof content === "object") {
      return get(content, this.get("nameProperty"));
    }

    return content;
  },

  _isNumeric(input) {
    return !isNaN(parseFloat(input)) && isFinite(input);
  },

  _castInteger(value) {
    if (this.get("castInteger") === true && Ember.isPresent(value) && this._isNumeric(value)) {
      return parseInt(value, 10);
    }

    return value;
  },

  _valueForContent(content) {
    switch (typeof content) {
    case "string":
    case "number":
      return content;
    default:
      return get(content, this.get("valueAttribute"));
    }
  },

  _contentForValue(value) {
    return this.get("content").find(c => {
      if (this._valueForContent(c) === value) { return true; }
    });
  },

  _computedContentForValue(value) {
    const searchedValue = value.toString();
    return this.get("computedContent").find(c => {
      if (c.value.toString() === searchedValue) { return true; }
    });
  },

  _originalValueForValue(value) {
    if (isNone(value)) { return null; }
    if (value === this.noneValue) { return this.noneValue; }

    const computedContent = this._computedContentForValue(value);

    if (isNone(computedContent)) { return value; }

    return get(computedContent.originalContent, this.get("valueAttribute"));
  },
});
