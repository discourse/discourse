import computed from 'ember-addons/ember-computed-decorators';
import { iconHTML } from "discourse-common/lib/icon-library";

export default Ember.Component.extend({
  layoutName: "select-box-kit/templates/components/select-box-kit/select-box-kit-row",

  classNames: "select-box-kit-row",

  tagName: "li",

  attributeBindings: ["title", "id:data-id"],

  classNameBindings: ["isHighlighted", "isSelected"],

  @computed("titleForRow")
  title(titleForRow) { return titleForRow(this); },

  @computed("templateForRow")
  template(templateForRow) { return templateForRow(this); },

  @computed("shouldHighlightRow", "highlightedValue")
  isHighlighted(shouldHighlightRow) { return shouldHighlightRow(this); },

  @computed("shouldSelectRow", "value")
  isSelected(shouldSelectRow) { return shouldSelectRow(this); },

  icon() {
    if (this.get("content.originalContent.icon")) {
      const iconName = this.get("content.originalContent.icon");
      const iconClass = this.get("content.originalContent.iconClass");
      return iconHTML(iconName, { class: iconClass });
    }

    return null;
  },

  sendOnHoverAction() {
    this.sendAction("onHover", this.get("content.value"));
  },

  mouseEnter() {
    Ember.run.debounce(this, this.sendOnHoverAction, 32);
  },

  click() {
    this.sendAction("onSelect", this.get("content.value"));
  }
});
