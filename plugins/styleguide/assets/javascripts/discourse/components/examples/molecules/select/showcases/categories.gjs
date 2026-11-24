import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
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
      @extraOptions={{@extraOptions}}
      @filterBy={{this.filter}}
      @identifier="sg-categories"
      @onChange={{this.update}}
      @options={{@options}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.showcases.categories.placeholder"
        )
      }}
      @value={{this.value}}
      @valueField="slug"
      @variant="button"
    >
      <:selection as |option|>
        {{dCategoryBadge option.record}}
      </:selection>

      <:option as |option|>
        <span class="select-showcases__category">
          <span class="select-showcases__category-status">
            {{dCategoryBadge
              option.record
              topicCount=option.record.topic_count
              readOnly=option.record.read_restricted
            }}
          </span>
          {{#if option.record.description_excerpt}}
            <span aria-hidden="true" class="select-showcases__category-desc">
              {{option.record.description_excerpt}}
            </span>
          {{/if}}
        </span>
      </:option>
    </DSelect>
  </template>
}
