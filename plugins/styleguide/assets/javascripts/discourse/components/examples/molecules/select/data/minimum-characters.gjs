import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { timezoneApi } from "../../../../../lib/select-fixtures.js";

export default class MinimumCharactersSelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @clearable={{true}}
      @identifier="sg-min-chars"
      @load={{timezoneApi.search}}
      @minChars={{3}}
      @onChange={{this.onChange}}
      @placeholder={{i18n
        "styleguide.sections.select.placeholders.search_cities"
      }}
      @resolveValue={{timezoneApi.find}}
      @value={{this.value}}
    />
  </template>
}
