import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

export default class CategoriesSelectExample extends Component {
  @tracked value = "support";

  @action
  filter(category, input) {
    const searchable = `${category.name} ${category.description_excerpt ?? ""}`;
    return searchable.toLowerCase().includes(input.toLowerCase());
  }

  @action
  update(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @filterBy={{this.filter}}
      @identifier="sg-categories"
      @items={{@items}}
      @onChange={{this.update}}
      @placeholder={{i18n
        "styleguide.sections.select.pickers.categories.placeholder"
      }}
      @specialItems={{@specialItems}}
      @value={{this.value}}
      @valueField="slug"
      @variant="button"
    >
      <:selection as |category|>
        {{dCategoryBadge category}}
      </:selection>

      <:item as |category|>
        <span class="select-showcases__category">
          <span class="select-showcases__category-status">
            {{dCategoryBadge
              category
              topicCount=category.topic_count
              readOnly=category.read_restricted
            }}
          </span>
          {{#if category.description_excerpt}}
            <span aria-hidden="true" class="select-showcases__category-desc">
              {{category.description_excerpt}}
            </span>
          {{/if}}
        </span>
      </:item>
    </DSelect>
  </template>
}
