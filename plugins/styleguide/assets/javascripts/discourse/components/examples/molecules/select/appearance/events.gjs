import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures";

export default class EventsSelectExample extends Component {
  @tracked value = null;
  @tracked openCount = 0;
  @tracked closeCount = 0;

  @action
  onChange(value) {
    this.value = value;
  }

  @action
  onShow() {
    this.openCount++;
  }

  @action
  onClose() {
    this.closeCount++;
  }

  <template>
    <DSelect
      @identifier="sg-events"
      @placement="top-start"
      @items={{LOCALES}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @onShow={{this.onShow}}
      @onClose={{this.onClose}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    />
    <output class="styleguide-example__result">
      {{i18n
        "styleguide.sections.select.events_note"
        opened=this.openCount
        closed=this.closeCount
      }}
    </output>
  </template>
}
