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
        class="input-setting-date"
        @disabled={{@disabled}}
        @type="date"
        @value={{@value}}
        {{on "input" this.changeValue}}
      />

      {{#if @value}}
        <DButton
          class="btn-small"
          @action={{this.reset}}
          @ariaLabel="admin.settings.reset"
          @disabled={{@disabled}}
          @icon="trash-can"
        />
      {{/if}}
    </div>
  </template>
}
