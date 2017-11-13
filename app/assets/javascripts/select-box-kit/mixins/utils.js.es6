const { get, isNone, guidFor, isPresent } = Ember;

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

  _castInteger(value) {
    if (this.get("castInteger") === true && isPresent(value)) {
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

  _findComputedContentByGuid(guid) {
    return this.get("computedContent").find(c => {
      return guidFor(c) === guid;
    });
  },

  _filterRemovableComputedContents(computedContent) {
    return computedContent.filter(c => {
      if (!this.get("_initialValues").includes(c.value)) {
        return true;
      }
      return false;
    });
  }
});
