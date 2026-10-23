import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { USER_GROUPS } from "../../../../../lib/select-fixtures.js";

export default class MaximumSelectExample extends Component {
  @tracked value = [1, 11, 14];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-maximum"
      @items={{USER_GROUPS}}
      @labelField="fullName"
      @maximum={{3}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @placeholder={{i18n
        "styleguide.sections.select.placeholders.choose_groups"
      }}
      @value={{this.value}}
    />
  </template>
}
