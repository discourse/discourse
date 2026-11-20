/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import ValueList from "discourse/admin/components/value-list";

@tagName("")
export default class List extends Component {
  <template>
    <div ...attributes>
      <ValueList
        @allowAny={{this.allowAny}}
        @choices={{this.setting.choices}}
        @disabled={{@disabled}}
        @inputDelimiter="|"
        @values={{this.value}}
      />
    </div>
  </template>
}
