import Component from "@ember/component";
import UtilsMixin from "select-kit/mixins/utils";
import { computed } from "@ember/object";
import { makeArray } from "discourse-common/lib/helpers";
import { schedule } from "@ember/runloop";

export default Component.extend(UtilsMixin, {
  eventType: "click",

  click(event) {
    if (typeof document === "undefined") {
      return;
    }
    if (this.isDestroyed || !this.selectKit || this.selectKit.isDisabled) {
      return;
    }
    if (this.eventType !== "click" || event.button !== 0) {
      return;
    }
    this.selectKit.toggle(event);
    event.preventDefault();
  },

  classNames: ["select-kit-header"],
  classNameBindings: ["isFocused"],
  attributeBindings: [
    "tabindex",
    "ariaOwns:aria-owns",
    "ariaHasPopup:aria-haspopup",
    "ariaIsExpanded:aria-expanded",
    "headerRole:role",
    "selectedValue:data-value",
    "selectedNames:data-name",
    "buttonTitle:title",
  ],

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

  ariaIsExpanded: computed("selectKit.isExpanded", function () {
    return this.selectKit.isExpanded ? "true" : "false";
  }),

  ariaHasPopup: "menu",

  ariaOwns: computed("selectKit.uniqueID", function () {
    return `${this.selectKit.uniqueID}-body`;
  }),

  headerRole: "listbox",

  tabindex: 0,

  didInsertElement() {
    this._super(...arguments);
    if (this.selectKit.options.autofocus) {
      this.set("isFocused", true);
    }
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
      if (this.selectKit.isExpanded) {
        this.selectKit.highlightPrevious();
      } else {
        this.selectKit.open(event);
      }
      return false;
    } else if (event.key === "ArrowDown") {
      if (this.selectKit.isExpanded) {
        this.selectKit.highlightNext();
      } else {
        this.selectKit.open(event);
      }
      return false;
    } else if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
      // Do nothing for left/right arrow
      return true;
    } else if (event.key === " ") {
      event.preventDefault(); // prevents the space to trigger a scroll page-next
      this.selectKit.toggle(event);
    } else if (event.key === "Escape") {
      this.selectKit.close(event);
    } else if (event.key === "Backspace") {
      this._focusFilterInput();
    } else if (event.key === "Tab") {
      if (
        this.selectKit.highlighted &&
        this.selectKit.isExpanded &&
        this.selectKit.options.triggerOnChangeOnTab
      ) {
        this.selectKit.select(
          this.getValue(this.selectKit.highlighted),
          this.selectKit.highlighted
        );
      }
      this.selectKit.close(event);
    } else if (
      this.selectKit.options.filterable ||
      this.selectKit.options.autoFilterable ||
      this.selectKit.options.allowAny
    ) {
      if (this.selectKit.isExpanded) {
        this._focusFilterInput();
      } else {
        this.selectKit.open(event);
        schedule("afterRender", () => this._focusFilterInput());
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
