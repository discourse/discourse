import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures.js";

export default class ListWrappingExample extends Component {
  @tracked value = ["ja"];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelectList
      class="select-examples__tag-list"
      @ariaLabel={{i18n "styleguide.sections.select.list_languages_label"}}
      @identifier="sg-list-wrapping"
      @items={{LOCALES}}
      @onChange={{this.onChange}}
      @searchPlaceholder={{i18n
        "styleguide.sections.select.placeholders.search_languages"
      }}
      @value={{this.value}}
      @virtualized={{false}}
    />
  </template>
}
