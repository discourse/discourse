import computed from 'ember-addons/ember-computed-decorators';
import { iconHTML } from "discourse-common/lib/icon-library";

export default Ember.Component.extend({
  layoutName: "components/select-box/select-box-row",

  classNames: "select-box-row",

  tagName: "li",

  attributeBindings: ["title", "id:data-id"],

  classNameBindings: ["isHighlighted:is-highlighted", "isSelected:is-selected"],

  @computed("titleForRow")
  title(titleForRow) { return titleForRow(this); },

  @computed("idForRow")
  id(idForRow) { return idForRow(this); },

  @computed("templateForRow")
  template(templateForRow) { return templateForRow(this); },

  @computed("shouldHighlightRow", "highlightedValue")
  isHighlighted(shouldHighlightRow) { return shouldHighlightRow(this); },

  @computed("shouldSelectRow", "value")
  isSelected(shouldSelectRow) { return shouldSelectRow(this); },

  icon() {
    if (this.get("content.icon")) {
      const iconName = this.get("content.icon");
      const iconClass = this.get("content.iconClass");
      return iconHTML(iconName, { class: iconClass });
    }

    return null;
  },

  mouseEnter() {
    this.sendAction("onHover", this.get("content"));
  },

  click() {
    this.sendAction("onSelect", this.get("content"));
  }
});
