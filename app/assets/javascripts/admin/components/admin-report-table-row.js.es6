import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "tr",
  classNames: ["admin-report-table-row"],

  @computed("data", "labels")
  cells(row, labels) {
    return labels.map(label => {
      return label.compute(row);
    });
  }
});
