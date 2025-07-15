import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import roundTime from "../../lib/round-time";

export default class TimeTraveller extends Component {
  get localTimeWithOffset() {
    let date = moment().add(this.args.localTimeOffset, "minutes");

    if (this.args.localTimeOffset) {
      date = roundTime(date);
    }

    return date.format("HH:mm");
  }

  @action
  reset() {
    this.args.setOffset(0);
  }

  @action
  sliderMoved(event) {
    const value = parseInt(event.target.value, 10);
    const offset = value * 15;
    this.args.setOffset(offset);
  }

  <template>
    <div class="group-timezones-time-traveler">
      <span class="time">
        {{this.localTimeWithOffset}}
      </span>

      <span class="discourse-group-timezones-slider-wrapper">
        <input
          class="group-timezones-slider"
          {{on "input" this.sliderMoved}}
          step="1"
          value="0"
          type="range"
          min="-48"
          max="48"
        />
      </span>

      <div class="group-timezones-reset">
        <DButton
          disabled={{not @localTimeOffset}}
          @action={{this.reset}}
          @icon="arrow-rotate-left"
        />
      </div>
    </div>
  </template>
}
