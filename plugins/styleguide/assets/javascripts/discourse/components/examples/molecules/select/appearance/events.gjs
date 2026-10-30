import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { TIMEZONES } from "../../../../../lib/select-fixtures.js";

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
      @items={{TIMEZONES}}
      @onChange={{this.onChange}}
      @onClose={{this.onClose}}
      @onShow={{this.onShow}}
      @placement="top-start"
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.placeholders.choose_timezone"
        )
      }}
      @value={{this.value}}
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
