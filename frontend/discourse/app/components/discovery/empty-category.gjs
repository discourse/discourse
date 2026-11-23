import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { getEditCategoryUrl } from "discourse/lib/url";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const DISCUSSION_TYPE = { id: "discussion", svg_icon: "comment" };

const CategoryTypeTile = <template>
  <span
    class="empty-category__type-tile {{concat '--category-type-' @type.id}}"
  >
    {{#if @type.svg_icon}}
      {{dIcon @type.svg_icon}}
    {{else}}
      {{dEmoji @type.icon alt="" skipTitle=true}}
    {{/if}}
  </span>
</template>;

export default class EmptyCategory extends Component {
  @service currentUser;

  // Prefers a specialised type (e.g. events) over the implicit discussion type.
  get categoryType() {
    const types = Object.values(this.args.category.category_types ?? {});
    return (
      types.find((type) => type.id !== DISCUSSION_TYPE.id) ??
      types[0] ??
      DISCUSSION_TYPE
    );
  }

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
      @body={{i18n "category.empty_state.body"}}
      @ctaAction={{@createTopic}}
      @ctaIcon="plus"
      @ctaLabel={{this.createTopicLabel}}
      @identifier="empty-category"
      @svgContent={{component CategoryTypeTile type=this.categoryType}}
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
