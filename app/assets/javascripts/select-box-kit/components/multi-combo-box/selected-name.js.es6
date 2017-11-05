export default Ember.Component.extend({
  attributeBindings: ["tabindex","content.name:data-name", "content.value:data-value"],
  classNames: "selected-name",
  classNameBindings: ["isHighlighted"],
  layoutName: "select-box-kit/templates/components/multi-combo-box/selected-name",
  tagName: "li",
  tabindex: -1,

  click() {
    this.toggleProperty("isHighlighted");
    return false;
  }
});
