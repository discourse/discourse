import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";

export default class Datetime extends Component {
  get localTime() {
    if (!this.args.value) {
      return "";
    }

    // Convert UTC ISO string to local datetime-local format
    return moment(this.args.value)
      .local()
      .format(moment.HTML5_FMT.DATETIME_LOCAL);
  }

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

  <template>
    <div class="date-time-setting">
      <Input
        class="input-setting-date"
        @disabled={{@disabled}}
        @type="datetime-local"
        @value={{this.localTime}}
        {{on "input" this.convertToUniversalTime}}
      />

      {{#if @value}}
        <DButton
          class="btn-small"
          @action={{this.reset}}
          @disabled={{@disabled}}
          @icon="trash-can"
        />
      {{/if}}
    </div>
  </template>
}
