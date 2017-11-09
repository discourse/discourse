import { iconHTML } from 'discourse-common/lib/icon-library';
import { on } from 'ember-addons/ember-computed-decorators';
import computed from 'ember-addons/ember-computed-decorators';
const { run, isPresent } = Ember;
import UtilsMixin from "select-box-kit/mixins/utils";

export default Ember.Component.extend(UtilsMixin, {
  layoutName: "select-box-kit/templates/components/select-box-kit/select-box-kit-row",
  classNames: "select-box-kit-row",
  tagName: "li",
  tabIndex: -1,
  attributeBindings: [
    "tabIndex",
    "title",
    "content.value:data-value",
    "content.name:data-name"
  ],
  classNameBindings: ["isHighlighted", "isSelected"],
  clicked: false,

  @computed("content.originalContent.title", "content.name")
  title(title, name) {
    return title || name;
  },

  @computed("templateForRow")
  template(templateForRow) { return templateForRow(this); },

  @on("didReceiveAttrs")
  _setSelectionState() {
    const contentValue = this.get("content.value");

    this.set("isSelected", this.get("value") === contentValue);
    this.set("isHighlighted", this.get("highlightedValue") === contentValue);
  },

  @on("willDestroyElement")
  _clearDebounce() {
    const hoverDebounce = this.get("hoverDebounce");
    if (isPresent(hoverDebounce)) { run.cancel(hoverDebounce); }
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
    this._sendOnSelectAction();
  },

  _sendOnSelectAction() {
    if (this.get("clicked") === false) {
      this.set("clicked", true);
      this.sendAction("onSelect", this.get("content.value"));
    }
  },

  _sendOnHighlightAction() {
    this.sendAction("onHighlight", this.get("content.value"));
  }
});
