import Component from "@ember/component";
import { computed } from "@ember/object";
import { makeArray } from "discourse-common/lib/helpers";
import { guidFor } from "@ember/object/internals";
import UtilsMixin from "select-kit/mixins/utils";

export default Component.extend(UtilsMixin, {
  layoutName: "select-kit/templates/components/select-kit/select-kit-row",
  classNames: ["select-kit-row"],
  tagName: "li",
  tabIndex: -1,
  attributeBindings: [
    "tabIndex",
    "title",
    "rowValue:data-value",
    "rowName:data-name",
    "ariaLabel:aria-label",
    "guid:data-guid"
  ],
  classNameBindings: [
    "isHighlighted",
    "isSelected",
    "isNone",
    "isNone:none",
    "item.classNames"
  ],

  isNone: computed("rowValue", function() {
    return this.rowValue === this.getValue(this.selectKit.noneItem);
  }),

  guid: computed("item", function() {
    return guidFor(this.item);
  }),

  ariaLabel: computed("item.ariaLabel", "title", function() {
    return this.getProperty(this.item, "ariaLabel") || this.title;
  }),

  title: computed("item.title", "rowName", function() {
    return this.getProperty(this.item, "title") || this.rowName;
  }),

  label: computed("item.label", "title", "rowName", function() {
    const label =
      this.getProperty(this.item, "label") || this.title || this.rowName;
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
      rowValue: this.getValue(this.item)
    });
  },

  icons: computed("item.{icon,icons}", function() {
    const icon = makeArray(this.getProperty(this.item, "icon"));
    const icons = makeArray(this.getProperty(this.item, "icons"));
    return icon.concat(icons).filter(Boolean);
  }),

  highlightedValue: computed("selectKit.highlighted", function() {
    return this.getValue(this.selectKit.highlighted);
  }),

  isHighlighted: computed("rowValue", "highlightedValue", function() {
    return this.rowValue === this.highlightedValue;
  }),

  isSelected: computed("rowValue", "value", function() {
    return this.rowValue === this.value;
  }),

  mouseEnter() {
    if (!this.isDestroying || !this.isDestroyed) {
      this.selectKit.onHover(this.rowValue, this.item);
    }
    return false;
  },

  click() {
    this.selectKit.select(this.rowValue, this.item);
    return false;
  }
});
