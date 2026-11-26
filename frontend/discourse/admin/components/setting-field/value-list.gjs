import Component from "@glimmer/component";
import { action } from "@ember/object";
import ValueList from "discourse/admin/components/value-list";

const TOKEN_SEPARATOR = "|";
const LINE_SEPARATOR = "\n";

export const VARIANTS = {
  list: { delimiter: TOKEN_SEPARATOR },
  value_list: { delimiter: LINE_SEPARATOR },
  url_list: {
    delimiter: LINE_SEPARATOR,
    addKey: "admin.site_settings.add_url",
  },
};

export default class SettingFieldValueList extends Component {
  get variant() {
    return VARIANTS[this.args.definition.type];
  }

  @action
  onChange(values) {
    this.args.field.set(values.join(this.variant.delimiter));
  }

  <template>
    <@field.Control>
      <ValueList
        @addKey={{this.variant.addKey}}
        @choices={{@definition.choices}}
        @disabled={{@field.disabled}}
        @inputDelimiter={{this.variant.delimiter}}
        @onChange={{this.onChange}}
        @values={{@field.value}}
      />
    </@field.Control>
  </template>
}
