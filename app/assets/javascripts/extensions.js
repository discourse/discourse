/* eslint-disable */
if (!Array.prototype.groupBy) {
  Object.defineProperty(Array.prototype, "groupBy", {
    value: function(predicate) {
      if (typeof predicate === "string") {
        return this.reduce((acc, item) => {
          (acc[item[predicate]] = acc[item[predicate]] || []).push(item);
          return acc;
        }, {});
      } else {
        throw new TypeError(
          "'" +
            typeof predicate +
            "' is not supported as predicate by Array.groupBy"
        );
      }
    },
    writable: true,
    configurable: true
  });
}
/* eslint-enable */
