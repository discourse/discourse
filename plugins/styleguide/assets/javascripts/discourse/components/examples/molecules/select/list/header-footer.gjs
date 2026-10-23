import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import { i18n } from "discourse-i18n";
import { delay, TAGS } from "../../../../../lib/select-fixtures.js";

export default class ListHeaderFooterExample extends Component {
  @tracked value = [];

  tags = TAGS;

  @action
  async load(filter, { signal }) {
    await delay(signal, 400);
    return TAGS.filter((tag) => tag.label.includes(filter.toLowerCase()));
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelectList
      class="select-examples__tag-list"
      @hideSelected={{true}}
      @identifier="sg-list-header-footer"
      @label={{i18n "styleguide.sections.select.list_tags_label"}}
      @labelField="label"
      @load={{this.load}}
      @maximum={{3}}
      @onChange={{this.onChange}}
      @searchPlaceholder={{i18n "styleguide.sections.select.list_search"}}
      @value={{this.value}}
      @valueField="slug"
      @valueItems={{this.tags}}
      @virtualized={{false}}
    >
      <:listHeader as |state|>
        {{#unless state.query}}
          <span>{{i18n "styleguide.sections.select.list_suggested"}}</span>
        {{/unless}}
      </:listHeader>
      <:footer as |state|>
        {{i18n
          "styleguide.sections.select.list_remaining"
          count=state.remaining
        }}
      </:footer>
    </DSelectList>
  </template>
}
