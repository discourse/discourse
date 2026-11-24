import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";
import { sortOrders } from "../../../../../lib/select-fixtures.js";

const RECOMMENDED = "top";

export default class SettingsOverFieldsSelectExample extends Component {
  @tracked value = "latest";

  items = sortOrders().map((order) =>
    order.id === RECOMMENDED
      ? selectOption(order, {
          label: i18n(
            "styleguide.sections.select.content.settings_recommended",
            {
              name: order.name,
            }
          ),
          icon: "star",
          description: i18n(
            "styleguide.sections.select.content.settings_recommended_description"
          ),
        })
      : order
  );

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @descriptionField="summary"
      @iconField="icon"
      @identifier="sg-settings-over-fields"
      @labelField="name"
      @onChange={{this.onChange}}
      @options={{this.items}}
      @value={{this.value}}
      @variant="static"
    />
  </template>
}
