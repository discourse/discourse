import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import FilterNavigationMenu from "discourse/components/discovery/filter-navigation-menu";
import { ajax } from "discourse/lib/ajax";

export default class PropertyEngineFilterQuery extends Component {
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
    this.args.onPatch?.({ [this.args.fieldName]: value });
  }

  <template>
    {{#if this.tips}}
      <FilterNavigationMenu
        @initialInputValue={{@value}}
        @onChange={{this.handleChange}}
        @tips={{this.tips}}
      />
    {{/if}}
  </template>
}
