import { action, computed } from "@ember/object";
import Component from "@ember/component";
import I18n from "I18n";
import UtilsMixin from "select-kit/mixins/utils";
import { guidFor } from "@ember/object/internals";
import layout from "select-kit/templates/components/select-kit/select-kit-row";
import { makeArray } from "discourse-common/lib/helpers";
import { reads } from "@ember/object/computed";

export default Component.extend(UtilsMixin, {
  layout,
  classNames: ["select-kit-row"],
  tagName: "li",
  tabIndex: -1,
  attributeBindings: [
    "tabIndex",
    "title",
    "rowValue:data-value",
    "rowName:data-name",
    "ariaLabel:aria-label",
    "ariaSelected:aria-selected",
    "guid:data-guid",
    "rowLang:lang",
    "role",
  ],
  classNameBindings: [
    "isHighlighted",
    "isSelected",
    "isNone",
    "isNone:none",
    "item.classNames",
  ],

  didInsertElement() {
    this._super(...arguments);
    this.element.addEventListener("mouseenter", this.handleMouseEnter);
  },

  willDestroyElement() {
    this._super(...arguments);
    if (this.element) {
      this.element.removeEventListener("mouseenter", this.handleMouseEnter);
    }
  },

  isNone: computed("rowValue", function () {
    return this.rowValue === this.getValue(this.selectKit.noneItem);
  }),

  role: "option",

  guid: computed("item", function () {
    return guidFor(this.item);
  }),

  lang: reads("item.lang"),

  ariaLabel: computed("item.ariaLabel", "title", function () {
    return this.getProperty(this.item, "ariaLabel") || this.title;
  }),

  ariaSelected: computed("isSelected", function () {
    return this.isSelected ? "true" : "false";
  }),

  title: computed("rowTitle", "item.title", "rowName", function () {
    return (
      this.rowTitle || this.getProperty(this.item, "title") || this.rowName
    );
  }),

  label: computed("rowLabel", "item.label", "title", "rowName", function () {
    const label =
      this.rowLabel ||
      this.getProperty(this.item, "label") ||
      this.title ||
      this.rowName;
    if (
      this.selectKit.options.allowAny &&
      this.rowValue === this.selectKit.filter &&
      this.getName(this.selectKit.noneItem) !== this.rowName &&
      this.getName(this.selectKit.newItem) === this.rowName
    ) {
      return I18n.t("select_kit.create", { content: label });
    }
    return label;
  }),

  didReceiveAttrs() {
    this._super(...arguments);

    this.setProperties({
      rowName: this.getName(this.item),
      rowValue: this.getValue(this.item),
      rowLabel: this.getProperty(this.item, "labelProperty"),
      rowTitle: this.getProperty(this.item, "titleProperty"),
      rowLang: this.getProperty(this.item, "langProperty"),
    });
  },

  icons: computed("item.{icon,icons}", function () {
    const icon = makeArray(this.getProperty(this.item, "icon"));
    const icons = makeArray(this.getProperty(this.item, "icons"));
    return icon.concat(icons).filter(Boolean);
  }),

  highlightedValue: computed("selectKit.highlighted", function () {
    return this.getValue(this.selectKit.highlighted);
  }),

  isHighlighted: computed("rowValue", "highlightedValue", function () {
    return this.rowValue === this.highlightedValue;
  }),

  isSelected: computed("rowValue", "value", function () {
    return this.rowValue === this.value;
  }),

  @action
  handleMouseEnter() {
    if (!this.isDestroying || !this.isDestroyed) {
      this.selectKit.onHover(this.rowValue, this.item);
    }
    return false;
  },

  click() {
    this.selectKit.select(this.rowValue, this.item);
    return false;
  },

  mouseDown(event) {
    if (this.selectKit.options.preventHeaderFocus) {
      event.preventDefault();
    }
  },
});
