import { on } from 'ember-addons/ember-computed-decorators';
import computed from 'ember-addons/ember-computed-decorators';
const { run } = Ember;

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
  isHighlighted(shouldHighlightRow) {
    return shouldHighlightRow(this);
  },

  @computed("shouldSelectRow", "computedValue.[]")
  isSelected(shouldSelectRow) {
    return shouldSelectRow(this);
  },

  @computed("iconForRow", "content.[]")
  icon(iconForRow) { return iconForRow(this); },

  @on("willDestroyElement")
  _clearDebounce() {
    const hoverDebounce = this.get("hoverDebounce");

    if (Ember.isPresent(hoverDebounce)) {
      run.cancel(hoverDebounce);
    }
  },

  mouseEnter() {
    this.set("hoverDebounce", run.debounce(this, this._sendOnHoverAction, 32));
  },

  click() {
    this.sendAction("onSelect", this.get("content.value"));
  },

  _sendOnHoverAction() {
    this.sendAction("onHover", this.get("content.value"));
  }
});
