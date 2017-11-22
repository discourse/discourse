const { get, isNone, guidFor } = Ember;

export default Ember.Mixin.create({
  valueForContentItem(content) {
    switch (typeof content) {
    case "string":
    case "number":
      return content;
    default:
      return get(content, this.get("valueAttribute"));
    }
  },

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
    if (this.get("castInteger") && Ember.isPresent(value) && this._isNumeric(value)) {
      return parseInt(value, 10);
    }

    return value;
  },

  _findComputedContentItemByGuid(guid) {
    return this.get("computedContent").find(c => {
      return guidFor(c) === guid;
    });
  },

  _filterRemovableComputedContents(computedContent) {
    return computedContent.filter(c => c.created === true);
  }
});
