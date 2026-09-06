import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";

export default class DateSetting extends Component {
  @action
  changeValue(event) {
    this.args.changeValueCallback(event.target.value);
  }

  @action
  reset() {
    this.args.changeValueCallback("");
  }

  <template>
    <div class="date-time-setting">
      <Input
        @type="date"
        @value={{@value}}
        @disabled={{@disabled}}
        class="input-setting-date"
        {{on "input" this.changeValue}}
      />

      {{#if @value}}
        <DButton
          @icon="trash-can"
          @action={{this.reset}}
          @disabled={{@disabled}}
          @ariaLabel="admin.settings.reset"
          class="btn-small"
        />
      {{/if}}
    </div>
  </template>
}
