import Component from "@glimmer/component";
import { action } from "@ember/object";
import SimpleList from "discourse/admin/components/simple-list";

const TOKEN_SEPARATOR = "|";

export default class SettingFieldSimpleList extends Component {
  @action
  onChange(values) {
    this.args.field.set(values.join(TOKEN_SEPARATOR));
  }

  <template>
    <@field.Control>
      <SimpleList
        @allowAny={{@definition.allow_any}}
        @choices={{@definition.choices}}
        @inputDelimiter={{TOKEN_SEPARATOR}}
        @onChange={{this.onChange}}
        @values={{@field.value}}
      />
    </@field.Control>
  </template>
}
