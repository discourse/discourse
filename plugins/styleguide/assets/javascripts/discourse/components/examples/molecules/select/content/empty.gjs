import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { emptyApi } from "../../../../../lib/select-fixtures.js";

export default class CustomEmptySelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-custom-empty"
      @load={{emptyApi.search}}
      @onChange={{this.onChange}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.placeholders.find_saved_search"
        )
      }}
      @value={{this.value}}
      @variant="button"
    >
      <:empty>
        {{i18n "styleguide.sections.select.content.empty_body"}}
      </:empty>
    </DSelect>
  </template>
}
