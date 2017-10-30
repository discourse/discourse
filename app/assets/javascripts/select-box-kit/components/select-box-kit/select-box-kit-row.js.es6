import { iconHTML } from 'discourse-common/lib/icon-library';
import { on } from 'ember-addons/ember-computed-decorators';
import computed from 'ember-addons/ember-computed-decorators';
const { run, isPresent } = Ember;
import UtilsMixin from "select-box-kit/mixins/utils";

export default Ember.Component.extend(UtilsMixin, {
  layoutName: "select-box-kit/templates/components/select-box-kit/select-box-kit-row",
  classNames: "select-box-kit-row",
  tagName: "li",
  attributeBindings: [
    "title",
    "content.value:data-value",
    "content.name:data-name"
  ],
  classNameBindings: ["isHighlighted", "isSelected"],

  title: Ember.computed.alias("content.name"),

  @computed("templateForRow")
  template(templateForRow) { return templateForRow(this); },

  @on("didReceiveAttrs")
  _setSelectionState() {
    const contentValue = this.get("content.value");
    this.set("isSelected", this.get("value") === contentValue);
    this.set("isHighlighted", this._castInteger(this.get("highlightedValue")) === this._castInteger(contentValue));
  },

  @on("willDestroyElement")
  _clearDebounce() {
    const hoverDebounce = this.get("hoverDebounce");

    if (isPresent(hoverDebounce)) {
      run.cancel(hoverDebounce);
    }
  },

  @computed("content.originalContent.icon", "content.originalContent.iconClass")
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
    this.sendAction("onSelect", this.get("content.value"));
  },

  _sendOnHighlightAction() {
    this.sendAction("onHighlight", this.get("content.value"));
  }
});
