import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class CategoryTypeCards extends Component {
  @service categoryTypeChooser;
  @service router;

  @action
  selectType(type) {
    this.categoryTypeChooser.choose(
      type.id,
      type.name,
      type.configuration_schema
    );
    this.router.transitionTo("newCategory.tabs", "general");
  }

  <template>
    <div class="category-type-cards">
      {{#each @types as |type|}}
        <button
          type="button"
          class="category-type-cards__card
            {{unless type.available '--unavailable'}}"
          disabled={{unless type.available true}}
          {{on "click" (fn this.selectType type)}}
        >
          <span class="category-type-cards__card-icon">
            {{icon type.icon}}
          </span>
          <span class="category-type-cards__card-name">
            {{type.name}}
          </span>
          {{#if type.description}}
            <span class="category-type-cards__card-description">
              {{type.description}}
            </span>
          {{/if}}
          {{#unless type.available}}
            <span class="category-type-cards__card-badge">
              {{i18n "category.choose_type.requires_plugin"}}
            </span>
          {{/unless}}
        </button>
      {{/each}}
    </div>
  </template>
}
