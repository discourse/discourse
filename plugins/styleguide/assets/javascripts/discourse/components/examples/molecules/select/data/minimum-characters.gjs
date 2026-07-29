import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { localeApi } from "../../../../../lib/select-fixtures";

export default class MinimumCharactersSelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-min-chars"
      @load={{localeApi.search}}
      @resolveValue={{localeApi.find}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @minChars={{3}}
      @clearable={{true}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    />
  </template>
}
