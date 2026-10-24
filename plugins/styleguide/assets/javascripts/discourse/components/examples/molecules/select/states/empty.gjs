import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { emptyApi } from "../../../../../lib/select-fixtures.js";

export default class EmptySelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-empty"
      @load={{emptyApi.search}}
      @noResultsLabel={{i18n "styleguide.sections.select.empty_channels_label"}}
      @onChange={{this.onChange}}
      @placeholder={{i18n
        "styleguide.sections.select.placeholders.search_archived_channels"
      }}
      @value={{this.value}}
      @variant="button"
    />
  </template>
}
