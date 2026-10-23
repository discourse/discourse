import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import { i18n } from "discourse-i18n";
import { TAGS } from "../../../../../lib/select-fixtures.js";

export default class ListHideSelectedExample extends Component {
  @tracked value = ["design-system", "accessibility"];

  tags = TAGS;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelectList
      class="select-examples__tag-list"
      @hideSelected={{true}}
      @identifier="sg-list-hide-selected"
      @items={{this.tags}}
      @label={{i18n "styleguide.sections.select.list_tags_label"}}
      @labelField="label"
      @onChange={{this.onChange}}
      @searchPlaceholder={{i18n "styleguide.sections.select.list_search"}}
      @value={{this.value}}
      @valueField="slug"
      @virtualized={{false}}
    />
  </template>
}
