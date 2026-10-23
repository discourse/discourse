import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import { i18n } from "discourse-i18n";
import { PEOPLE } from "../../../../../lib/select-fixtures.js";

export default class ListHideSelectedExample extends Component {
  @tracked value = [101, 104];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelectList
      class="select-examples__tag-list"
      @hideSelected={{true}}
      @identifier="sg-list-hide-selected"
      @items={{PEOPLE}}
      @label={{i18n "styleguide.sections.select.list_people_label"}}
      @labelField="name"
      @onChange={{this.onChange}}
      @searchPlaceholder={{i18n
        "styleguide.sections.select.placeholders.search_people"
      }}
      @value={{this.value}}
      @virtualized={{false}}
    />
  </template>
}
