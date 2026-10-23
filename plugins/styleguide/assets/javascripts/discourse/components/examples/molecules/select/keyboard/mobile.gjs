import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { TEAM_MEMBERS } from "../../../../../lib/select-fixtures.js";

export default class MobileSelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-keyboard-mobile"
      @items={{TEAM_MEMBERS}}
      @labelField="name"
      @onChange={{this.onChange}}
      @placeholder={{i18n
        "styleguide.sections.select.placeholders.find_person"
      }}
      @value={{this.value}}
    />
  </template>
}
