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
  tabIndex: 0,
  attributeBindings: [
    "tabIndex",
    "title",
    "rowValue:data-value",
    "rowName:data-name",
    "ariaLabel:aria-label",
    "role",
    "ariaSelected:aria-selected",
    "guid:data-guid",
    "rowLang:lang",
  ],
  classNameBindings: [
    "isHighlighted",
    "isSelected",
    "isNone",
    "isNone:none",
    "item.classNames",
  ],

  role: "region",

  didInsertElement() {
    this._super(...arguments);
    this.element.addEventListener("mouseenter", this.handleMouseEnter);
    this.element.addEventListener("focus", this.handleMouseEnter);
    this.element.addEventListener("blur", this.handleBlur);
  },

  willDestroyElement() {
    this._super(...arguments);
    if (this.element) {
      this.element.removeEventListener("mouseenter", this.handleBlur);
      this.element.removeEventListener("focus", this.handleMouseEnter);
      this.element.removeEventListener("blur", this.handleMouseEnter);
    }
  },

  isNone: computed("rowValue", function () {
    return this.rowValue === this.getValue(this.selectKit.noneItem);
  }),

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
      this.element.focus({ preventScroll: true });
      this.selectKit.onHover(this.rowValue, this.item);
    }
    return false;
  },

  @action
  handleBlur(event) {
    if ((!this.isDestroying || !this.isDestroyed) && event.relatedTarget) {
      if (!this.selectKit.mainElement().contains(event.relatedTarget)) {
        this.selectKit.mainElement().open = false;
      }
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

  keyDown(event) {
    if (this.selectKit.isExpanded) {
      if (event.keyCode === 38) {
        this.selectKit.highlightPrevious();
        return false;
      } else if (event.keyCode === 40) {
        this.selectKit.highlightNext();
        return false;
      } else if (event.keyCode === 13) {
        this.selectKit.select(
          this.getValue(this.selectKit.highlighted),
          this.selectKit.highlighted
        );
        return false;
      } else if (event.keyCode === 27) {
        this.selectKit.mainElement().open = false;
        this.selectKit.headerElement().focus();
      }
    }
  },
});
