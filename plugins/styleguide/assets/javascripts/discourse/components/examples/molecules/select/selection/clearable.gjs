import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { PEOPLE } from "../../../../../lib/select-fixtures.js";

export default class ClearableSelectExample extends Component {
  @tracked value = 103;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @clearable={{true}}
      @identifier="sg-clearable"
      @items={{PEOPLE}}
      @onChange={{this.onChange}}
      @texts={{hash
        placeholder=(i18n "styleguide.sections.select.placeholders.assign_to")
      }}
      @value={{this.value}}
    />
  </template>
}
