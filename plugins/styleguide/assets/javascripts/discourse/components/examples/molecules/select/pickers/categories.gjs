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
      @identifier="sg-categories"
      @items={{@items}}
      @value={{this.value}}
      @onChange={{this.update}}
      @variant="button"
      @valueField="slug"
      @filterBy={{this.filter}}
      @specialItems={{@specialItems}}
      @placeholder={{i18n
        "styleguide.sections.select.pickers.categories.placeholder"
      }}
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
            <span class="select-showcases__category-desc" aria-hidden="true">
              {{category.description_excerpt}}
            </span>
          {{/if}}
        </span>
      </:item>
    </DSelect>
  </template>
}
