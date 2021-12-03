import Component from "@ember/component";
import UtilsMixin from "select-kit/mixins/utils";
import { computed } from "@ember/object";
import { makeArray } from "discourse-common/lib/helpers";

export default Component.extend(UtilsMixin, {
  classNames: ["select-kit-header"],
  classNameBindings: ["isFocused"],
  attributeBindings: [
    "role",
    "tabindex",
    "selectedValue:data-value",
    "selectedNames:data-name",
    "buttonTitle:title",
    "selectKit.options.autofocus:autofocus",
  ],

  selectKit: null,

  role: "listbox",

  tabindex: 0,

  selectedValue: computed("value", function () {
    return this.value === this.getValue(this.selectKit.noneItem)
      ? null
      : makeArray(this.value).join(",");
  }),

  selectedNames: computed("selectedContent.[]", function () {
    return makeArray(this.selectedContent)
      .map((s) => this.getName(s))
      .join(",");
  }),

  buttonTitle: computed("value", "selectKit.noneItem", function () {
    if (
      !this.value &&
      this.selectKit.noneItem &&
      !this.selectKit.options.showFullTitle
    ) {
      return this.selectKit.noneItem.title || this.selectKit.noneItem.name;
    }
  }),

  icons: computed("selectKit.options.{icon,icons}", function () {
    const icon = makeArray(this.selectKit.options.icon);
    const icons = makeArray(this.selectKit.options.icons);
    return icon.concat(icons).filter(Boolean);
  }),

  didInsertElement() {
    this._super(...arguments);
    if (this.selectKit.options.autofocus) {
      this.set("isFocused", true);
    }
  },

  mouseDown() {
    return false;
  },

  click(event) {
    event.preventDefault();
    event.stopPropagation();

    this.selectKit.toggle(event);
  },

  keyUp(event) {
    if (event.key === " ") {
      event.preventDefault();
    }
  },

  keyDown(event) {
    if (this.selectKit.isDisabled) {
      return;
    }

    if (!this.selectKit.onKeydown(event)) {
      return false;
    }

    const onlyShiftKey = event.shiftKey && event.key === "Shift";
    if (event.metaKey || onlyShiftKey) {
      return;
    }

    if (event.key === "Enter") {
      event.stopPropagation();

      if (this.selectKit.isExpanded) {
        if (this.selectKit.highlighted) {
          this.selectKit.select(
            this.getValue(this.selectKit.highlighted),
            this.selectKit.highlighted
          );
          return false;
        }
      } else {
        this.selectKit.close(event);
      }
    } else if (event.key === "ArrowUp") {
      event.stopPropagation();

      if (this.selectKit.isExpanded) {
        this.selectKit.highlightPrevious();
      } else {
        this.selectKit.open(event);
      }
      return false;
    } else if (event.key === "ArrowDown") {
      event.stopPropagation();
      if (this.selectKit.isExpanded) {
        this.selectKit.highlightNext();
      } else {
        this.selectKit.open(event);
      }
      return false;
    } else if (event.key === " ") {
      event.stopPropagation();
      event.preventDefault(); // prevents the space to trigger a scroll page-next
      this.selectKit.open(event);
    } else if (event.key === "Escape") {
      event.stopPropagation();
      if (this.selectKit.isExpanded) {
        this.selectKit.close(event);
      } else {
        this.element.blur();
      }
    } else if (event.key === "Tab") {
      return true;
    } else if (event.key === "Backspace") {
      this._focusFilterInput();
    } else if (
      this.selectKit.options.filterable ||
      this.selectKit.options.autoFilterable ||
      this.selectKit.options.allowAny
    ) {
      if (this.selectKit.isExpanded) {
        this._focusFilterInput();
      } else {
        if (this.isValidInput(event.key)) {
          this.selectKit.set("filter", event.key);
          this.selectKit.open(event);
          event.preventDefault();
          event.stopPropagation();
        }
      }
    } else {
      if (this.selectKit.isExpanded) {
        return false;
      } else {
        return true;
      }
    }
  },

  _focusFilterInput() {
    const filterContainer = document.querySelector(
      `#${this.selectKit.uniqueID}-filter`
    );

    if (filterContainer) {
      filterContainer.style.display = "flex";

      const filterInput = filterContainer.querySelector(".filter-input");
      filterInput && filterInput.focus();
    }
  },
});
