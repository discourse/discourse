import { action, computed } from "@ember/object";
import Component from "@ember/component";
import I18n from "I18n";
import UtilsMixin from "select-kit/mixins/utils";
import { guidFor } from "@ember/object/internals";
import layout from "select-kit/templates/components/select-kit/select-kit-row";
import { makeArray } from "discourse-common/lib/helpers";
import { reads } from "@ember/object/computed";
import { dasherize } from "@ember/string";

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
    "index:data-index",
    "role",
    "ariaChecked:aria-checked",
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
  index: 0,

  role: "menuitemradio",

  didInsertElement() {
    this._super(...arguments);

    if (!this?.site?.mobileView) {
      this.element.addEventListener("mouseenter", this.handleMouseEnter);
      this.element.addEventListener("focus", this.handleMouseEnter);
      this.element.addEventListener("blur", this.handleBlur);
    }
  },

  willDestroyElement() {
    this._super(...arguments);
    if (!this?.site?.mobileView && this.element) {
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

  ariaChecked: computed("isSelected", function () {
    return this.isSelected ? "true" : "false";
  }),

  title: computed("rowTitle", "item.title", "rowName", function () {
    return (
      this.rowTitle || this.getProperty(this.item, "title") || this.rowName
    );
  }),

  dasherizedTitle: computed("title", function () {
    return dasherize((this.title || "").replace(".", "-"));
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

  @action
  handleBlur(event) {
    if (
      (!this.isDestroying || !this.isDestroyed) &&
      event.target &&
      this.selectKit.mainElement()
    ) {
      if (!this.selectKit.mainElement().contains(event.target)) {
        this.selectKit.close(event);
      }
    }
    return false;
  },

  click(event) {
    event.preventDefault();
    event.stopPropagation();
    this.selectKit.select(this.rowValue, this.item);
    return false;
  },

  mouseDown(event) {
    if (this.selectKit.options.preventHeaderFocus) {
      event.preventDefault();
    }
  },

  focusIn(event) {
    event.stopImmediatePropagation();
  },

  keyDown(event) {
    if (this.selectKit.isExpanded) {
      if (event.key === "Backspace") {
        if (this.selectKit.isFilterExpanded) {
          this.selectKit.set("filter", this.selectKit.filter.slice(0, -1));
          this.selectKit.triggerSearch();
          this.selectKit.focusFilter();
          event.preventDefault();
          event.stopPropagation();
          return false;
        }
      } else if (event.key === "ArrowUp") {
        this.selectKit.highlightPrevious();
        return false;
      } else if (event.key === "ArrowDown") {
        this.selectKit.highlightNext();
        return false;
      } else if (event.key === "Enter") {
        event.stopImmediatePropagation();

        this.selectKit.select(
          this.getValue(this.selectKit.highlighted),
          this.selectKit.highlighted
        );
        return false;
      } else if (event.key === "Escape") {
        this.selectKit.close(event);
        this.selectKit.headerElement().focus();
      } else {
        if (this.isValidInput(event.key)) {
          this.selectKit.set("filter", event.key);
          this.selectKit.triggerSearch();
          this.selectKit.focusFilter();
          event.preventDefault();
          event.stopPropagation();
        }
      }
    }
  },
});
