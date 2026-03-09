import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import emoji from "discourse/helpers/emoji";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default class CategoryTypeCards extends Component {
  @service categoryTypeChooser;
  @service router;

  @action
  selectType(type) {
    this.categoryTypeChooser.choose(
      type.id,
      type.name,
      type.configuration_schema,
      type.title
    );
    this.router.transitionTo("newCategory.tabs", "general");
  }

  <template>
    <div class="category-type-cards">
      {{#each @types as |type|}}
        <div
          class={{concatClass
            "category-type-cards__card"
            (unless type.available "--unavailable")
            (concat "--category-type-" type.id)
          }}
        >
          <button
            type="button"
            class="category-type-cards__card-select"
            disabled={{unless type.available true}}
            {{on "click" (fn this.selectType type)}}
          >
            <span class="category-type-cards__card-icon">
              {{emoji type.icon alt="" skipTitle=true}}
            </span>
            <span class="category-type-cards__card-name">
              {{type.name}}
            </span>
            {{#if type.description}}
              <span class="category-type-cards__card-description">
                {{type.description}}
              </span>
            {{/if}}
          </button>
          {{#unless type.available}}
            <span class="category-type-cards__card-badge">
              <PluginOutlet
                @name="category-type-card-top-right-corner"
                @outletArgs={{lazyHash type=type}}
              >
                {{i18n "category.choose_type.requires_plugin"}}
              </PluginOutlet>
            </span>
          {{/unless}}
          <div class="category-type-cards__card-bottom">
            <PluginOutlet
              @name="category-type-card-bottom"
              @outletArgs={{lazyHash type=type}}
            />
          </div>
        </div>
      {{/each}}
    </div>
  </template>
}
