import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { ACTIVITY_FILTERS } from "../../../../../lib/select-fixtures.js";

export default class StaticSelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-static"
      @items={{ACTIVITY_FILTERS}}
      @onChange={{this.onChange}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.placeholders.filter_activity"
        )
      }}
      @value={{this.value}}
      @variant="static"
    />
  </template>
}
