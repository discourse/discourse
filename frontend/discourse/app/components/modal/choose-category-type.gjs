import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DModal from "discourse/components/d-modal";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class ChooseCategoryType extends Component {
  @tracked loading = true;
  @tracked types = [];

  @bind
  async loadTypes() {
    try {
      const result = await ajax("/categories/types");
      this.types = result.types;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  @action
  selectType(type) {
    if (!type.available) {
      return;
    }
    this.args.closeModal({
      categoryType: type.id,
      categoryTypeName: type.name,
      categoryTypeSchema: type.configuration_schema,
    });
  }

  <template>
    <DModal
      @title={{i18n "category.choose_type.title"}}
      @closeModal={{@closeModal}}
      {{didInsert this.loadTypes}}
      class="choose-category-type-modal"
    >
      <:body>
        <ConditionalLoadingSpinner @condition={{this.loading}}>
          <div class="choose-category-type-modal__grid">
            {{#each this.types as |type|}}
              <button
                type="button"
                class="choose-category-type-modal__card
                  {{unless type.available '--unavailable'}}"
                disabled={{unless type.available true}}
                {{on "click" (fn this.selectType type)}}
              >
                <span class="choose-category-type-modal__card-icon">
                  {{icon type.icon}}
                </span>
                <span class="choose-category-type-modal__card-name">
                  {{type.name}}
                </span>
                {{#if type.description}}
                  <span class="choose-category-type-modal__card-description">
                    {{type.description}}
                  </span>
                {{/if}}
                {{#unless type.available}}
                  <span class="choose-category-type-modal__card-badge">
                    {{i18n "category.choose_type.requires_plugin"}}
                  </span>
                {{/unless}}
              </button>
            {{/each}}
          </div>
        </ConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
