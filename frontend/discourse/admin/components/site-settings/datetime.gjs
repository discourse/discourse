import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";

export default class DateTimeSetting extends Component {
  @action
  convertToUniversalTime(event) {
    const datetime = event.target.value;
    if (!datetime) {
      this.args.changeValueCallback("");
      return;
    }

    // Convert local datetime-local to UTC ISO string
    const utcValue = moment(datetime).utc().format();
    this.args.changeValueCallback(utcValue);
  }

  @action
  reset() {
    this.args.changeValueCallback("");
  }

  get localTime() {
    if (!this.args.value) {
      return "";
    }

    // Convert UTC ISO string to local datetime-local format
    return moment(this.args.value)
      .local()
      .format(moment.HTML5_FMT.DATETIME_LOCAL);
  }

  <template>
    <div class="date-time-setting">
      <Input
        @type="datetime-local"
        @value={{this.localTime}}
        @disabled={{@disabled}}
        class="input-setting-date"
        {{on "input" this.convertToUniversalTime}}
      />

      {{#if @value}}
        <DButton
          @icon="trash-can"
          @action={{this.reset}}
          @disabled={{@disabled}}
          class="btn-small"
        />
      {{/if}}
    </div>
  </template>
}
