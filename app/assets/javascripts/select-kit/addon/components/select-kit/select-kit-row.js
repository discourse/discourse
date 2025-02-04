import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { reads } from "@ember/object/computed";
import { guidFor } from "@ember/object/internals";
import { dasherize } from "@ember/string";
import {
  attributeBindings,
  classNameBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
import { i18n } from "discourse-i18n";
import UtilsMixin from "select-kit/mixins/utils";

@classNames("select-kit-row")
@tagName("li")
@attributeBindings(
  "tabIndex",
  "title",
  "rowValue:data-value",
  "rowName:data-name",
  "index:data-index",
  "role",
  "ariaChecked:aria-checked",
  "guid:data-guid",
  "rowLang:lang"
)
@classNameBindings(
  "isHighlighted",
  "isSelected",
  "isNone",
  "isNone:none",
  "item.classNames"
)
export default class SelectKitRow extends Component.extend(UtilsMixin) {
  tabIndex = 0;
  index = 0;
  role = "menuitemradio";

  @reads("item.lang") lang;
  didInsertElement() {
    super.didInsertElement(...arguments);

    if (this.site.desktopView) {
      this.element.addEventListener("mouseenter", this.handleMouseEnter);
      this.element.addEventListener("focus", this.handleMouseEnter);
    }
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    if (this.site.desktopView) {
      this.element.removeEventListener("mouseenter", this.handleMouseEnter);
      this.element.removeEventListener("focus", this.handleMouseEnter);
    }
  }

  @computed("rowValue")
  get isNone() {
    return this.rowValue === this.getValue(this.selectKit.noneItem);
  }

  @computed("item")
  get guid() {
    return guidFor(this.item);
  }

  @computed("isSelected")
  get ariaChecked() {
    return this.isSelected ? "true" : "false";
  }

  @computed("rowTitle", "item.title", "rowName")
  get title() {
    return (
      this.rowTitle || this.getProperty(this.item, "title") || this.rowName
    );
  }

  @computed("title")
  get dasherizedTitle() {
    return dasherize((this.title || "").replace(".", "-"));
  }

  @computed("rowLabel", "item.label", "title", "rowName")
  get label() {
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
      return i18n("select_kit.create", { content: label });
    }
    return label;
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    this.setProperties({
      rowName: this.getName(this.item),
      rowValue: this.getValue(this.item),
      rowLabel: this.getProperty(this.item, "labelProperty"),
      rowTitle: this.getProperty(this.item, "titleProperty"),
      rowLang: this.getProperty(this.item, "langProperty"),
    });
  }

  @computed("item.{icon,icons}")
  get icons() {
    const icon = makeArray(this.getProperty(this.item, "icon"));
    const icons = makeArray(this.getProperty(this.item, "icons"));
    return icon.concat(icons).filter(Boolean);
  }

  @computed("selectKit.highlighted")
  get highlightedValue() {
    return this.getValue(this.selectKit.highlighted);
  }

  @computed("rowValue", "highlightedValue")
  get isHighlighted() {
    return this.rowValue === this.highlightedValue;
  }

  @computed("rowValue", "value")
  get isSelected() {
    return this.rowValue === this.value;
  }

  @action
  handleMouseEnter() {
    if (!this.isDestroying || !this.isDestroyed) {
      this.selectKit.onHover(this.rowValue, this.item);
    }
    return false;
  }

  click(event) {
    event.preventDefault();
    event.stopPropagation();
    this.selectKit.select(this.rowValue, this.item);
    return false;
  }

  mouseDown(event) {
    if (this.selectKit.options.preventHeaderFocus) {
      event.preventDefault();
    }
  }

  focusIn(event) {
    event.stopImmediatePropagation();
  }

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
        event.preventDefault();
        event.stopPropagation();
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
  }
}
