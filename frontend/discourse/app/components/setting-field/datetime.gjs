import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";

export default class SettingFieldDatetime extends Component {
  get localTime() {
    const { value } = this.args.field;

    return value
      ? moment(value).local().format(moment.HTML5_FMT.DATETIME_LOCAL)
      : "";
  }

  @action
  onInput(event) {
    const localTime = event.target.value;

    this.args.field.set(localTime ? moment(localTime).utc().format() : "");
  }

  <template>
    <@field.Control>
      <input
        aria-describedby={{@field.describedBy}}
        aria-invalid={{if @field.error "true"}}
        class="form-kit__control-input"
        disabled={{@field.disabled}}
        id={{@field.id}}
        name={{@field.name}}
        type="datetime-local"
        value={{this.localTime}}
        {{on "input" this.onInput}}
      />
    </@field.Control>
  </template>
}
