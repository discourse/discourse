import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import Category from "discourse/models/category";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import CategorySelector from "discourse/select-kit/components/category-selector";
import ExpressionWrapper from "./expression-wrapper";

function categoryIdsFromValue(value) {
  if (value == null || value === "") {
    return [];
  }

  return (Array.isArray(value) ? value : [value])
    .map((id) => parseInt(id, 10))
    .filter((id) => !isNaN(id));
}

export default class CategoryControl extends Component {
  @service siteSettings;

  @tracked selectedCategories = [];

  constructor() {
    super(...arguments);
    this.pendingCategoriesRequest = Promise.resolve();

    if (this.multiple) {
      this.hydrateSelectedCategories();
    }
  }

  get multiple() {
    return Boolean(this.args.schema?.ui?.multiple);
  }

  get clearable() {
    return (
      !this.args.schema?.required &&
      this.siteSettings.allow_uncategorized_topics
    );
  }

  get categoryIds() {
    return categoryIdsFromValue(this.args.field.value);
  }

  async updateSelectedCategories(previousRequest) {
    const requestedIds = this.categoryIds;

    let categories;
    try {
      categories = await Category.asyncFindByIds(requestedIds);
    } catch {
      return;
    }

    await previousRequest;

    if (
      this.isDestroying ||
      this.isDestroyed ||
      !this.#sameIds(this.categoryIds, requestedIds)
    ) {
      return;
    }

    this.selectedCategories = categories.filter(Boolean);
  }

  @action
  hydrateSelectedCategories() {
    const ids = this.categoryIds;
    if (
      this.#sameIds(
        ids,
        this.selectedCategories.map((category) => category.id)
      )
    ) {
      return;
    }

    const previousRequest = this.pendingCategoriesRequest;
    this.pendingCategoriesRequest =
      this.updateSelectedCategories(previousRequest);
  }

  #sameIds(a, b) {
    return a.length === b.length && a.every((id, index) => id === b[index]);
  }

  @action
  handleChange(categoryId) {
    this.args.field.set(categoryId == null ? "" : String(categoryId));
  }

  @action
  handleMultiChange(categories) {
    categories = categories || [];
    this.selectedCategories = categories;
    this.args.field.set(categories.map((category) => category.id));
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @schema={{@schema}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
      @dynamicValueHint={{@dynamicValueHint}}
      @session={{@session}}
    >
      {{#if this.multiple}}
        <CategorySelector
          {{didUpdate this.hydrateSelectedCategories @field.value}}
          @categories={{this.selectedCategories}}
          @onChange={{this.handleMultiChange}}
          @options={{hash translatedNone=@placeholder}}
        />
      {{else}}
        <CategoryChooser
          @value={{if @field.value @field.value null}}
          @onChange={{this.handleChange}}
          @options={{hash clearable=this.clearable}}
        />
      {{/if}}
    </ExpressionWrapper>
  </template>
}
