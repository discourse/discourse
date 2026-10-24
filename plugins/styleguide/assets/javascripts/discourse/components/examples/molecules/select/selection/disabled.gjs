import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { notificationLevels } from "../../../../../lib/select-fixtures.js";

export default class DisabledSelectExample extends Component {
  @tracked value = "watching";

  items = notificationLevels();

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @disabled={{true}}
      @identifier="sg-disabled"
      @items={{this.items}}
      @labelField="title"
      @onChange={{this.onChange}}
      @placeholder={{i18n
        "styleguide.sections.select.placeholders.choose_notification_level"
      }}
      @value={{this.value}}
      @valueField="level"
      @variant="static"
    />
  </template>
}
