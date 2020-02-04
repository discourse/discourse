import { computed } from "@ember/object";
import Component from "@ember/component";
import UtilsMixin from "select-kit/mixins/utils";
import { schedule } from "@ember/runloop";
import { makeArray } from "discourse-common/lib/helpers";

export default Component.extend(UtilsMixin, {
  eventType: "click",

  click(event) {
    if (typeof document === "undefined") return;
    if (this.isDestroyed || !this.selectKit || this.selectKit.isDisabled)
      return;
    if (this.eventType !== "click" || event.button !== 0) return;
    this.selectKit.toggle(event);
  },

  classNames: ["select-kit-header"],
  classNameBindings: ["isFocused"],
  attributeBindings: [
    "tabindex",
    "ariaOwns:aria-owns",
    "ariaHasPopup:aria-haspopup",
    "ariaIsExpanded:aria-expanded",
    "selectKitId:data-select-kit-id",
    "roleButton:role",
    "selectedValue:data-value",
    "selectedNames:data-name",
    "serializedNames:title"
  ],

  selectedValue: computed("value", function() {
    return this.value === this.getValue(this.selectKit.noneItem)
      ? null
      : makeArray(this.value).join(",");
  }),

  selectedNames: computed("selectedContent.[]", function() {
    return makeArray(this.selectedContent)
      .map(s => this.getName(s))
      .join(",");
  }),

  icons: computed("selectKit.options.{icon,icons}", function() {
    const icon = makeArray(this.selectKit.options.icon);
    const icons = makeArray(this.selectKit.options.icons);
    return icon.concat(icons).filter(Boolean);
  }),

  selectKitId: computed("selectKit.uniqueID", function() {
    return `${this.selectKit.uniqueID}-header`;
  }),

  ariaIsExpanded: computed("selectKit.isExpanded", function() {
    return this.selectKit.isExpanded ? "true" : "false";
  }),

  ariaHasPopup: true,

  ariaOwns: computed("selectKit.uniqueID", function() {
    return `[data-select-kit-id=${this.selectKit.uniqueID}-body]`;
  }),

  roleButton: "button",

  tabindex: 0,

  keyUp(event) {
    if (event.keyCode === 32) {
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

    const onlyShiftKey = event.shiftKey && event.keyCode === 16;
    if (event.metaKey || onlyShiftKey) {
      return;
    }

    if (event.keyCode === 13) {
      // Enter
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
    } else if (event.keyCode === 38) {
      // Up arrow
      if (this.selectKit.isExpanded) {
        this.selectKit.highlightPrevious();
      } else {
        this.selectKit.open(event);
      }
      return false;
    } else if (event.keyCode === 40) {
      // Down arrow
      if (this.selectKit.isExpanded) {
        this.selectKit.highlightNext();
      } else {
        this.selectKit.open(event);
      }
      return false;
    } else if (event.keyCode === 37 || event.keyCode === 39) {
      // Do nothing for left/right arrow
      return true;
    } else if (event.keyCode === 32) {
      // Space
      event.preventDefault(); // prevents the space to trigger a scroll page-next
      this.selectKit.toggle(event);
    } else if (event.keyCode === 27) {
      // Escape
      this.selectKit.close(event);
    } else if (event.keyCode === 8) {
      // Backspace
      this._focusFilterInput();
    } else if (event.keyCode === 9) {
      // Tab
      if (this.selectKit.highlighted && this.selectKit.isExpanded) {
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
      `[data-select-kit-id=${this.selectKit.uniqueID}-filter]`
    );

    if (filterContainer) {
      filterContainer.style.display = "flex";

      const filterInput = filterContainer.querySelector(".filter-input");
      filterInput && filterInput.focus();
    }
  }
});
