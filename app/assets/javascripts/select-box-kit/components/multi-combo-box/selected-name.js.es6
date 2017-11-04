export default Ember.Component.extend({
  attributeBindings: ["tabIndx","content.name:data-name", "content.value:data-value"],
  classNames: "selected-name",
  classNameBindings: ["isHighlighted"],
  layoutName: "select-box-kit/templates/components/multi-combo-box/selected-name",
  tagName: "li",
  tabIndex: "-1",

  click() {
    this.toggleProperty("isHighlighted");
    return false;
  }
});
