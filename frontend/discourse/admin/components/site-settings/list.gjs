/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import ValueList from "discourse/admin/components/value-list";

@tagName("")
export default class List extends Component {
  <template>
    <div ...attributes>
      <ValueList
        @values={{this.value}}
        @inputDelimiter="|"
        @choices={{this.setting.choices}}
        @disabled={{@disabled}}
      />
    </div>
  </template>
}
