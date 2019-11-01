import Component from "@ember/component";
import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
const { run, isPresent, makeArray, isEmpty } = Ember;
import UtilsMixin from "select-kit/mixins/utils";

export default Component.extend(UtilsMixin, {
  layoutName: "select-kit/templates/components/select-kit/select-kit-row",
  classNames: ["select-kit-row"],
  tagName: "li",
  tabIndex: -1,
  attributeBindings: [
    "tabIndex",
    "title",
    "value:data-value",
    "name:data-name",
    "ariaLabel:aria-label",
    "guid:data-guid"
  ],
  classNameBindings: [
    "isHighlighted",
    "isSelected",
    "computedContent.originalContent.classNames"
  ],

  forceEscape: Ember.computed.alias("options.forceEscape"),

  ariaLabel: Ember.computed.or("computedContent.ariaLabel", "title"),

  @computed("computedContent.title", "name")
  title(computedContentTitle, name) {
    if (computedContentTitle) return computedContentTitle;
    if (name) return name;

    return null;
  },

  @computed("computedContent")
  guid(computedContent) {
    return Ember.guidFor(computedContent);
  },

  label: Ember.computed.or("computedContent.label", "title", "name"),

  name: Ember.computed.alias("computedContent.name"),

  value: Ember.computed.alias("computedContent.value"),

  @computed("templateForRow")
  template(templateForRow) {
    return templateForRow(this);
  },

  @on("didReceiveAttrs")
  _setSelectionState() {
    this.setProperties({
      isSelected: this.computedValue === this.value,
      isHighlighted: this.get("highlighted.value") === this.value
    });
  },

  @on("willDestroyElement")
  _clearDebounce() {
    const hoverDebounce = this.hoverDebounce;
    if (isPresent(hoverDebounce)) {
      run.cancel(hoverDebounce);
    }
  },

  @computed(
    "computedContent.icon",
    "computedContent.icons",
    "computedContent.originalContent.icon"
  )
  icons(icon, icons, originalIcon) {
    return makeArray(icon)
      .concat(icons)
      .concat(makeArray(originalIcon))
      .filter(i => !isEmpty(i));
  },

  mouseEnter() {
    this.set(
      "hoverDebounce",
      run.debounce(this, this._sendMouseoverAction, 32)
    );
  },

  click() {
    this.onClickRow(this.computedContent);
  },

  _sendMouseoverAction() {
    this.onMouseoverRow(this.computedContent);
  }
});
