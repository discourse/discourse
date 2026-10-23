import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { TAGS } from "../../../../../lib/select-fixtures.js";

export default class ClearableMultipleSelectExample extends Component {
  @tracked value = ["accessibility", "performance"];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @clearable={{true}}
      @identifier="sg-clearable-multi"
      @items={{TAGS}}
      @labelField="label"
      @multiple={{true}}
      @onChange={{this.onChange}}
      @placeholder={{i18n
        "styleguide.sections.select.placeholders.choose_tags"
      }}
      @value={{this.value}}
      @valueField="slug"
    />
  </template>
}
