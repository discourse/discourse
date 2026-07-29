import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectDivider } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";
import { TIMEZONES } from "../../../../../lib/select-fixtures";

export default class DividerSelectExample extends Component {
  @tracked value = null;

  items = [
    TIMEZONES.find((zone) => zone.id === "Europe/London"),
    TIMEZONES.find((zone) => zone.id === "America/New_York"),
    selectDivider(),
    ...TIMEZONES.filter(
      (zone) => !["Europe/London", "America/New_York"].includes(zone.id)
    ),
  ];

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
