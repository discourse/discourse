import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import FilterNavigationMenu from "discourse/components/discovery/filter-navigation-menu";
import { ajax } from "discourse/lib/ajax";
import ExpressionWrapper from "./expression-wrapper";

const FILTER_OPTIONS_URLS = {
  posts: "/admin/plugins/discourse-workflows/filter-options/posts.json",
  topics: "/filter.json",
};

export default class FilterQuery extends Component {
  @tracked tips = null;

  constructor() {
    super(...arguments);
    this.loadTips();
  }

  get filterType() {
    return this.args.schema?.ui?.filter || "topics";
  }

  get optionsUrl() {
    return FILTER_OPTIONS_URLS[this.filterType] || FILTER_OPTIONS_URLS.topics;
  }

  async loadTips() {
    try {
      const result = await ajax(this.optionsUrl);
      this.tips =
        result.topic_list?.filter_option_info ||
        result.filter_option_info ||
        [];
    } catch {
      this.tips = [];
    }
  }

  @action
  handleChange(value) {
    this.args.field.set(value);
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @schema={{@schema}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
      @dynamicValueHint={{@dynamicValueHint}}
      @session={{@session}}
    >
      {{#if this.tips}}
        <FilterNavigationMenu
          @initialInputValue={{@field.value}}
          @onChange={{this.handleChange}}
          @placeholder={{@placeholder}}
          @tips={{this.tips}}
        />
      {{/if}}
    </ExpressionWrapper>
  </template>
}
