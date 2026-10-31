import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { TIMEZONES } from "../../../../../lib/select-fixtures.js";

export default class NoneSelectExample extends Component {
  @tracked value = "papeete";

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-none"
      @items={{TIMEZONES}}
      @noneRow={{true}}
      @onChange={{this.onChange}}
      @texts={{hash
        noneLabel=(i18n "styleguide.sections.select.none_label")
        placeholder=(i18n
          "styleguide.sections.select.placeholders.choose_timezone"
        )
      }}
      @value={{this.value}}
    />
  </template>
}
