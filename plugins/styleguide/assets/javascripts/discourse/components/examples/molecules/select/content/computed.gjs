import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { TIMEZONES } from "../../../../../lib/select-fixtures";

const hourCycle = new Intl.DateTimeFormat(undefined, {
  hour: "numeric",
}).resolvedOptions().hourCycle;

function localTimeIn(timeZone, now) {
  return new Intl.DateTimeFormat(undefined, {
    hour: "numeric",
    hourCycle,
    minute: "2-digit",
    timeZone,
  }).format(now);
}

export default class ComputedSelectExample extends Component {
  @tracked now = new Date();
  @tracked value = "london";

  #clockTimer = null;

  willDestroy() {
    super.willDestroy();
    this.#stopClock();
  }

  @action
  onChange(value) {
    this.value = value;
  }

  @action
  onClose() {
    this.#stopClock();
  }

  @action
  onShow() {
    this.#stopClock();
    this.now = new Date();
    this.#clockTimer = setInterval(() => {
      if (!this.isDestroying) {
        this.now = new Date();
      }
    }, 1_000);
  }

  #stopClock() {
    if (this.#clockTimer) {
      clearInterval(this.#clockTimer);
      this.#clockTimer = null;
    }
  }

  <template>
    <DSelect
      @identifier="sg-content-computed"
      @items={{TIMEZONES}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @onShow={{this.onShow}}
      @onClose={{this.onClose}}
      @placeholder={{i18n
        "styleguide.sections.select.content.computed_placeholder"
      }}
    >
      <:item as |zone|>
        <span class="select-examples__row select-examples__row--glyph">
          <span class="select-examples__timezone-offset">{{zone.offset}}</span>
          <span class="select-examples__primary">{{zone.name}}</span>
          <span class="select-examples__meta">
            {{localTimeIn zone.timeZone this.now}}
          </span>
        </span>
      </:item>
    </DSelect>
  </template>
}
