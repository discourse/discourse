import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import Category from "discourse/models/category";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import CategorySelector from "discourse/select-kit/components/category-selector";
import { integerIdsFromValue, sameIds } from "../../../lib/workflows/id-values";
import ExpressionWrapper from "./expression-wrapper";

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
    return integerIdsFromValue(this.args.field.value);
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

    if (this.isDestroying || !sameIds(this.categoryIds, requestedIds)) {
      return;
    }

    this.selectedCategories = categories.filter(Boolean);
  }

  @action
  hydrateSelectedCategories() {
    const ids = this.categoryIds;
    if (
      sameIds(
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
      @dynamicValueHint={{@dynamicValueHint}}
      @field={{@field}}
      @placeholder={{@placeholder}}
      @schema={{@schema}}
      @session={{@session}}
      @supportsExpression={{@supportsExpression}}
    >
      {{#if this.multiple}}
        <CategorySelector
          @categories={{this.selectedCategories}}
          @onChange={{this.handleMultiChange}}
          @options={{hash translatedNone=@placeholder}}
          {{didUpdate this.hydrateSelectedCategories @field.value}}
        />
      {{else}}
        <CategoryChooser
          @onChange={{this.handleChange}}
          @options={{hash clearable=this.clearable}}
          @value={{if @field.value @field.value null}}
        />
      {{/if}}
    </ExpressionWrapper>
  </template>
}
