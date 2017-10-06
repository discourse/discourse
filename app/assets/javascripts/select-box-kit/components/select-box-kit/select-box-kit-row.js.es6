import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  layoutName: "select-box-kit/templates/components/select-box-kit/select-box-kit-row",
  classNames: "select-box-kit-row",
  tagName: "li",
  attributeBindings: [
    "title",
    "content.value:data-value",
    "content.name:data-name"
  ],
  classNameBindings: ["isHighlighted", "isSelected"],

  @computed("titleForRow")
  title(titleForRow) { return titleForRow(this); },

  @computed("templateForRow")
  template(templateForRow) { return templateForRow(this); },

  @computed("shouldHighlightRow", "highlightedValue")
  isHighlighted(shouldHighlightRow) { return shouldHighlightRow(this); },

  @computed("shouldSelectRow", "value")
  isSelected(shouldSelectRow) { return shouldSelectRow(this); },

  @computed("iconForRow", "content.[]")
  icon(iconForRow) { return iconForRow(this); },

  mouseEnter() {
    Ember.run.debounce(this, this._sendOnHoverAction, 32);
  },

  click() {
    this.sendAction("onSelect", this.get("content.value"));
  },

  _sendOnHoverAction() {
    this.sendAction("onHover", this.get("content.value"));
  },
});
