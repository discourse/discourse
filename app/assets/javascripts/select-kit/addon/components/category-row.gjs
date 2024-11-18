import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty, isNone } from "@ember/utils";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import concatClass from "discourse/helpers/concat-class";
import dirSpan from "discourse/helpers/dir-span";
import Category from "discourse/models/category";

export default class CategoryRow extends Component {
  @service site;
  @service siteSettings;

  get isNone() {
    return this.rowValue === this.args.selectKit?.noneItem;
  }

  get highlightedValue() {
    return this.args.selectKit.get("highlighted.id");
  }

  get isHighlighted() {
    return this.rowValue === this.highlightedValue;
  }

  get isSelected() {
    return this.rowValue === this.args.value;
  }

  get hideParentCategory() {
    return this.args.selectKit.options.hideParentCategory;
  }

  get categoryLink() {
    return this.args.selectKit.options.categoryLink;
  }

  get countSubcategories() {
    return this.args.selectKit.options.countSubcategories;
  }

  get allowUncategorizedTopics() {
    return this.siteSettings.hideParentCategory;
  }

  get allowUncategorized() {
    return this.args.selectKit.options.allowUncategorized;
  }

  get rowName() {
    return this.args.item?.name;
  }

  get rowValue() {
    return this.args.item?.id;
  }

  get guid() {
    return guidFor(this.args.item);
  }

  get label() {
    return this.args.item?.name || this.args.item?.label;
  }

  get displayCategoryDescription() {
    const option = this.args.selectKit.options.displayCategoryDescription;
    if (isNone(option)) {
      return true;
    }

    return option;
  }

  get title() {
    if (this.category) {
      return this.categoryName;
    }
  }

  get categoryName() {
    return this.category.displayName;
  }

  get categoryDescriptionText() {
    return this.category.descriptionText;
  }

  @cached
  get category() {
    if (isEmpty(this.rowValue)) {
      const uncategorized = Category.findUncategorized();
      if (uncategorized && uncategorized.name === this.rowName) {
        return uncategorized;
      }
    } else {
      return Category.findById(parseInt(this.rowValue, 10));
    }
  }

  @cached
  get badgeForCategory() {
    return htmlSafe(
      categoryBadgeHTML(this.category, {
        link: this.categoryLink,
        allowUncategorized:
          this.allowUncategorizedTopics || this.allowUncategorized,
        hideParent: !!this.parentCategory,
        topicCount: this.topicCount,
        subcategoryCount: this.args.item?.category
          ? this.category.subcategory_count
          : 0,
      })
    );
  }

  @cached
  get badgeForParentCategory() {
    return htmlSafe(
      categoryBadgeHTML(this.parentCategory, {
        link: this.categoryLink,
        allowUncategorized:
          this.allowUncategorizedTopics || this.allowUncategorized,
        recursive: true,
      })
    );
  }

  get parentCategory() {
    return Category.findById(this.parentCategoryId);
  }

  get hasParentCategory() {
    return this.parentCategoryId;
  }

  get parentCategoryId() {
    return this.category?.parent_category_id;
  }

  get categoryTotalTopicCount() {
    return this.category?.totalTopicCount;
  }

  get categoryTopicCount() {
    return this.category?.topic_count;
  }

  get topicCount() {
    return this.countSubcategories
      ? this.categoryTotalTopicCount
      : this.categoryTopicCount;
  }

  get shouldDisplayDescription() {
    return (
      this.displayCategoryDescription &&
      this.categoryDescriptionText &&
      this.categoryDescriptionText !== "null"
    );
  }

  @cached
  get descriptionText() {
    if (this.categoryDescriptionText) {
      return this._formatDescription(this.categoryDescriptionText);
    }
  }

  @action
  handleMouseEnter() {
    if (this.site.mobileView) {
      return;
    }

    if (!this.isDestroying || !this.isDestroyed) {
      this.args.selectKit.onHover(this.rowValue, this.args.item);
    }
    return false;
  }

  @action
  handleClick(event) {
    event.preventDefault();
    event.stopPropagation();
    this.args.selectKit.select(this.rowValue, this.args.item);
    return false;
  }

  @action
  handleMouseDown(event) {
    if (this.args.selectKit.options.preventHeaderFocus) {
      event.preventDefault();
    }
  }

  @action
  handleFocusIn(event) {
    event.stopImmediatePropagation();
  }

  @action
  handleKeyDown(event) {
    if (this.args.selectKit.isExpanded) {
      if (event.key === "Backspace") {
        if (this.args.selectKit.isFilterExpanded) {
          this.args.selectKit.set(
            "filter",
            this.args.selectKit.filter.slice(0, -1)
          );
          this.args.selectKit.triggerSearch();
          this.args.selectKit.focusFilter();
          event.preventDefault();
          event.stopPropagation();
        }
      } else if (event.key === "ArrowUp") {
        this.args.selectKit.highlightPrevious();
        event.preventDefault();
      } else if (event.key === "ArrowDown") {
        this.args.selectKit.highlightNext();
        event.preventDefault();
      } else if (event.key === "Enter") {
        event.stopImmediatePropagation();
        this.args.selectKit.select(
          this.args.selectKit.highlighted.id,
          this.args.selectKit.highlighted
        );
        event.preventDefault();
      } else if (event.key === "Escape") {
        this.args.selectKit.close(event);
        this.args.selectKit.headerElement().focus();
        event.preventDefault();
        event.stopPropagation();
      } else {
        if (this._isValidInput(event.key)) {
          this.args.selectKit.set("filter", event.key);
          this.args.selectKit.triggerSearch();
          this.args.selectKit.focusFilter();
          event.preventDefault();
          event.stopPropagation();
        }
      }
    }
  }

  _formatDescription(description) {
    const limit = 200;
    return `${description.slice(0, limit)}${
      description.length > limit ? "&hellip;" : ""
    }`;
  }
  _isValidInput(eventKey) {
    // relying on passing the event to the input is risky as it could not work
    // dispatching the event won't work as the event won't be trusted
    // safest solution is to filter event and prefill filter with it
    const nonInputKeysRegex =
      /F\d+|Arrow.+|Meta|Alt|Control|Shift|Delete|Enter|Escape|Tab|Space|Insert|Backspace/;
    return !nonInputKeysRegex.test(eventKey);
  }

  <template>
    {{! template-lint-disable no-pointer-down-event-binding }}
    <div
      class={{concatClass
        "category-row"
        "select-kit-row"
        (if this.isSelected "is-selected")
        (if this.isHighlighted "is-highlighted")
        (if this.isNone "is-none")
      }}
      role="menuitemradio"
      data-index={{@index}}
      data-name={{this.rowName}}
      data-value={{this.rowValue}}
      data-title={{this.title}}
      title={{this.title}}
      data-guid={{this.guid}}
      {{on "focusin" this.handleFocusIn}}
      {{on "mousedown" this.handleMouseDown}}
      {{on "mouseenter" this.handleMouseEnter passive=true}}
      {{on "click" this.handleClick}}
      {{on "keydown" this.handleKeyDown}}
      aria-checked={{this.isSelected}}
      tabindex="0"
    >

      {{#if this.category}}
        <div class="category-status">
          {{#if this.hasParentCategory}}
            {{#unless this.hideParentCategory}}
              {{this.badgeForParentCategory}}
            {{/unless}}
          {{/if}}
          {{this.badgeForCategory}}
        </div>

        {{#if this.shouldDisplayDescription}}
          <div class="category-desc" aria-hidden="true">
            {{dirSpan this.descriptionText htmlSafe="true"}}
          </div>
        {{/if}}
      {{else}}
        {{htmlSafe this.label}}
      {{/if}}
    </div>
  </template>
}
