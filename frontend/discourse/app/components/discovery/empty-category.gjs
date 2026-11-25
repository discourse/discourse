import Component from "@glimmer/component";
import { service } from "@ember/service";
import SvgEmptyTopicList from "discourse/components/svg/empty-topic-list";
import categoryColorVariable from "discourse/helpers/category-color-variable";
import { getEditCategoryUrl } from "discourse/lib/url";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import { i18n } from "discourse-i18n";

export default class EmptyCategory extends Component {
  @service currentUser;

  get createTopicLabel() {
    if (this.currentUser && !this.args.createTopicDisabled) {
      return i18n("category.empty_state.create_topic");
    }
  }

  get editCategoryUrl() {
    if (this.args.category.can_edit) {
      return getEditCategoryUrl(this.args.category);
    }
  }

  <template>
    <DEmptyState
      style={{categoryColorVariable @category.color}}
      @body={{i18n "category.empty_state.body"}}
      @ctaAction={{@createTopic}}
      @ctaIcon="plus"
      @ctaLabel={{this.createTopicLabel}}
      @identifier="empty-category"
      @svgContent={{SvgEmptyTopicList}}
      @title={{i18n "category.empty_state.title"}}
    >
      <:actions>
        {{#if this.editCategoryUrl}}
          <a
            class="empty-state__secondary-action"
            href={{this.editCategoryUrl}}
          >
            {{i18n "category.empty_state.edit_category"}}
          </a>
        {{/if}}
      </:actions>
    </DEmptyState>
  </template>
}
