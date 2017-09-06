import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  layoutName: "components/select-box/select-box-row",

  classNames: "select-box-row",

  tagName: "li",

  attributeBindings: ["title"],

  classNameBindings: ["isHighlighted:is-highlighted"],

  @computed("titleForRow")
  title(titleForRow) {
    return titleForRow(this);
  },

  @computed("templateForRow")
  template(templateForRow) {
    return templateForRow(this);
  },

  @computed("shouldHighlightRow", "value")
  isHighlighted(shouldHighlightRow) {
    return shouldHighlightRow(this);
  },

  mouseEnter() {
    this.sendAction("onHover", this.get("content"));
  },

  click() {
    this.sendAction("onSelect", this.get("content"));
  }
});
