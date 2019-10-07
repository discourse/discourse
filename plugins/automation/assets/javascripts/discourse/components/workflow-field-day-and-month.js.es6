export default Ember.Component.extend({
  from: null,
  to: null,

  actions: {
    onChange(range) {
      this.setProperties(range);
      const format = "YYYY-MM-DD";
      this.onChange(
        [
          range.from && moment(range.from).format(format),
          range.to && moment(range.to).format(format)
        ]
          .filter(Boolean)
          .join(",")
      );
    }
  }
});
