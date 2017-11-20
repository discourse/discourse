import { iconHTML } from 'discourse-common/lib/icon-library';
import { on } from 'ember-addons/ember-computed-decorators';
import computed from 'ember-addons/ember-computed-decorators';
const { run, isPresent } = Ember;
import UtilsMixin from "select-kit/mixins/utils";

export default Ember.Component.extend(UtilsMixin, {
  layoutName: "select-kit/templates/components/select-kit/select-kit-row",
  classNames: ["select-kit-row", "select-box-kit-row"],
  tagName: "li",
  tabIndex: -1,
  attributeBindings: [
    "tabIndex",
    "title",
    "computedContent.value:data-value",
    "computedContent.name:data-name"
  ],
  classNameBindings: ["isHighlighted", "isSelected"],

  @computed("computedContent.originalContent.title", "computedContent.name")
  title(title, name) {
    return title || name;
  },

  @computed("templateForRow")
  template(templateForRow) { return templateForRow(this); },

  @on("didReceiveAttrs")
  _setSelectionState() {
    const contentValue = this.get("computedContent.value");

    this.set("isSelected", this.get("computedValue") === contentValue);
    this.set("isHighlighted", this.get("highlightedValue") === contentValue);
  },

  @on("willDestroyElement")
  _clearDebounce() {
    const hoverDebounce = this.get("hoverDebounce");
    if (isPresent(hoverDebounce)) { run.cancel(hoverDebounce); }
  },

  @computed("computedContent.originalContent.icon", "computedContent.originalContent.iconClass")
  icon(icon, cssClass) {
    if (icon) {
      return iconHTML(icon, { class: cssClass });
    }

    return null;
  },

  mouseEnter() {
    this.set("hoverDebounce", run.debounce(this, this._sendOnHighlightAction, 32));
  },

  click() {
    this.sendAction("onSelect", this.get("computedContent"));
  },

  _sendOnHighlightAction() {
    this.sendAction("onHighlight", this.get("computedContent"));
  }
});
