import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectDivider } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";
import { TIMEZONES } from "../../../../../lib/select-fixtures";

export default class DividerSelectExample extends Component {
  @tracked value = null;

  items = TIMEZONES.flatMap((zone, index) => {
    if (
      index > 0 &&
      zone.offsetMinutes !== TIMEZONES[index - 1].offsetMinutes
    ) {
      return [selectDivider(), zone];
    }

    return zone;
  });

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-divided"
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @placeholder={{i18n
        "styleguide.sections.select.content.divided_placeholder"
      }}
    />
  </template>
}
