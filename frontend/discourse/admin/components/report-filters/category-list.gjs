import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import Category from "discourse/models/category";
import MultipleCategoriesSelector from "discourse/select-kit/components/multiple-categories-selector";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import { i18n } from "discourse-i18n";

export default class CategoryList extends FilterComponent {
  @service siteSettings;

  @tracked selectedCategories;

  constructor() {
    super(...arguments);
    this.selectedCategories = (this.args.filter?.default || [])
      .map((id) => Category.findById(id))
      .filter(Boolean);
  }

  @action
  onChange(categories) {
    this.selectedCategories = categories;
  }

  @action
  onClose() {
    const ids = this.selectedCategories.map((category) => category.id);
    const current = this.args.filter.default || [];

    // apply (and re-run the report) only once the picker closes, and only when
    // the selection actually changed, so each individual pick doesn't refetch
    if (
      ids.length === current.length &&
      ids.every((id) => current.includes(id))
    ) {
      return;
    }

    this.args.applyFilter(this.args.filter.id, ids.length ? ids : undefined);
  }

  <template>
    <div ...attributes>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectCategory
          class="multiple-categories-selector"
          @disabled={{@filter.disabled}}
          @legacyKind="multiple-categories-selector"
          @multiple={{true}}
          @onChange={{this.onChange}}
          @onClose={{this.onClose}}
          @texts={{hash placeholder=(i18n "category.all")}}
          @value={{this.selectedCategories}}
        />
      {{else}}
        <MultipleCategoriesSelector
          @categories={{this.selectedCategories}}
          @onChange={{this.onChange}}
          @onClose={{this.onClose}}
          @options={{hash disabled=@filter.disabled none="category.all"}}
        />
      {{/if}}
    </div>
  </template>
}
