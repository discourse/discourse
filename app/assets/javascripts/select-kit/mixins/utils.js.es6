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

  _normalize(input) {
    input = input.toLowerCase();

    if (typeof input.normalize === "function") {
      input = input.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    }

    return input;
  },

  _cast(value) {
    if (value === this.noneValue) return value;
    return this._castInteger(this._castBoolean(value));
  },

  _castBoolean(value) {
    if (
      this.get("castBoolean") &&
      Ember.isPresent(value) &&
      typeof value === "string"
    ) {
      return value === "true";
    }

    return value;
  },

  _castInteger(value) {
    if (
      this.get("castInteger") &&
      Ember.isPresent(value) &&
      this._isNumeric(value)
    ) {
      return parseInt(value, 10);
    }

    return value;
  },

  _findComputedContentItemByGuid(guid) {
    if (guidFor(this.get("createRowComputedContent")) === guid) {
      return this.get("createRowComputedContent");
    }

    if (guidFor(this.get("noneRowComputedContent")) === guid) {
      return this.get("noneRowComputedContent");
    }

    return this.get("collectionComputedContent").find(c => {
      return guidFor(c) === guid;
    });
  },

  _filterRemovableComputedContents(computedContent) {
    return computedContent.filter(c => c.created);
  }
});
