import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  layoutName: "components/select-box/select-box-row",

  classNames: "select-box-row",

  tagName: "li",

  attributeBindings: ["title"],

  classNameBindings: ["isHighlighted:is-highlighted", "isSelected:is-selected"],

  @computed("titleForRow")
  title(titleForRow) {
    return titleForRow(this);
  },

  @computed("templateForRow")
  template(templateForRow) {
    return templateForRow(this);
  },

  @computed("shouldHighlightRow", "highlightedValue")
  isHighlighted(shouldHighlightRow) {
    return shouldHighlightRow(this);
  },

  @computed("shouldSelectRow", "value")
  isSelected(shouldSelectRow) {
    return shouldSelectRow(this);
  },

  mouseEnter() {
    this.sendAction("onHover", this.get("content"));
  },

  click() {
    this.sendAction("onSelect", this.get("content"));
  }
});
