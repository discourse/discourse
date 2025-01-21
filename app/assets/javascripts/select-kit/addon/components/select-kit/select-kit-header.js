import Component from "@ember/component";
import { computed } from "@ember/object";
import {
  attributeBindings,
  classNameBindings,
  classNames,
} from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
import UtilsMixin from "select-kit/mixins/utils";

@classNames("select-kit-header")
@classNameBindings("isFocused")
@attributeBindings(
  "role",
  "tabindex",
  "selectedValue:data-value",
  "selectedNames:data-name",
  "buttonTitle:title",
  "selectKit.options.autofocus:autofocus"
)
export default class SelectKitHeader extends Component.extend(UtilsMixin) {
  selectKit = null;
  role = "listbox";
  tabindex = 0;

  @computed("value")
  get selectedValue() {
    return this.value === this.getValue(this.selectKit.noneItem)
      ? null
      : makeArray(this.value).join(",");
  }

  @computed("selectedContent.[]")
  get selectedNames() {
    return makeArray(this.selectedContent)
      .map((s) => this.getName(s))
      .join(",");
  }

  @computed("value", "selectKit.noneItem")
  get buttonTitle() {
    if (
      !this.value &&
      this.selectKit.noneItem &&
      !this.selectKit.options.showFullTitle
    ) {
      return this.selectKit.noneItem.title || this.selectKit.noneItem.name;
    }
  }

  @computed("selectKit.options.{icon,icons}")
  get icons() {
    const icon = makeArray(this.selectKit.options.icon);
    const icons = makeArray(this.selectKit.options.icons);
    return icon.concat(icons).filter(Boolean);
  }

  didInsertElement() {
    super.didInsertElement(...arguments);
    if (this.selectKit.options.autofocus) {
      this.set("isFocused", true);
    }
  }

  mouseDown() {
    return false;
  }

  click(event) {
    event.preventDefault();
    event.stopPropagation();

    if (
      event.target?.classList.contains("selected-choice") ||
      event.target.parentNode?.classList.contains("selected-choice")
    ) {
      return false;
    }
    this.selectKit.toggle(event);
  }

  keyUp(event) {
    if (event.key === " ") {
      event.preventDefault();
    }
  }

  keyDown(event) {
    if (
      this.selectKit.isDisabled ||
      this.selectKit.options.disabled ||
      this.selectKit.options.useHeaderFilter
    ) {
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
  }

  _focusFilterInput() {
    const filterContainer = document.querySelector(
      `#${this.selectKit.uniqueID}-filter`
    );

    if (filterContainer) {
      filterContainer.style.display = "flex";

      const filterInput = filterContainer.querySelector(".filter-input");
      filterInput && filterInput.focus();
    }
  }
}
