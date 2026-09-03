import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { notificationLevels } from "../../../../../lib/select-fixtures";

export default class IconOnlySelectExample extends Component {
  @tracked value = "watching";

  get items() {
    return notificationLevels();
  }

  get icon() {
    return this.items.find((item) => item.level === this.value)?.icon ?? "bell";
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-icon-only"
      @items={{this.items}}
      @variant="static"
      @value={{this.value}}
      @onChange={{this.onChange}}
      @valueField="level"
      @labelField="title"
      @icon={{this.icon}}
      @iconOnly={{true}}
      @label={{i18n "styleguide.sections.select.icon_only_label"}}
    />
  </template>
}
