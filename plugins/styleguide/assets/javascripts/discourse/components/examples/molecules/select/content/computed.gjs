import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { localTimeIn, TIMEZONES } from "../../../../../lib/select-fixtures";

export default class ComputedSelectExample extends Component {
  @tracked value = "Europe/London";

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-content-computed"
      @items={{TIMEZONES}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @placeholder={{i18n
        "styleguide.sections.select.content.computed_placeholder"
      }}
    >
      <:item as |zone|>
        <span class="select-examples__row select-examples__row--glyph">
          {{dIcon "clock"}}
          <span class="select-examples__primary">{{zone.name}}</span>
          <span class="select-examples__meta">{{localTimeIn zone.id}}</span>
        </span>
      </:item>
    </DSelect>
  </template>
}
