import computed from 'ember-addons/ember-computed-decorators';
import { iconHTML } from 'discourse-common/helpers/fa-icon';

export default Em.Component.extend({
  tagName: "li",
  attributeBindings: ["data-poll-option-id"],

  "data-poll-option-id": Em.computed.alias("option.id"),

  @computed("option.selected", "isMultiple")
  optionIcon(selected, isMultiple) {
    if (isMultiple) {
      return iconHTML(selected ? 'check-square-o' : 'square-o');
    } else {
      return iconHTML(selected ? 'dot-circle-o' : 'circle-o');
    }
  },

  click(e) {
    // ensure we're not clicking on a link
    if ($(e.target).closest("a").length === 0) {
      this.sendAction("toggle", this.get("option"));
    }
  }
});
