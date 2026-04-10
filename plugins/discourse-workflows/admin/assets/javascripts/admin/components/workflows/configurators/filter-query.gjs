import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import FilterNavigationMenu from "discourse/components/discovery/filter-navigation-menu";
import { ajax } from "discourse/lib/ajax";
import ExpressionWrapper from "./expression-wrapper";

export default class FilterQuery extends Component {
  @tracked tips = null;

  constructor() {
    super(...arguments);
    this.loadTips();
  }

  async loadTips() {
    try {
      const result = await ajax("/filter.json");
      this.tips = result.topic_list?.filter_option_info || [];
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
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
    >
      {{#if this.tips}}
        <FilterNavigationMenu
          @initialInputValue={{@field.value}}
          @onChange={{this.handleChange}}
          @tips={{this.tips}}
        />
      {{/if}}
    </ExpressionWrapper>
  </template>
}
