import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { USER_GROUPS } from "../../../../../lib/select-fixtures.js";

const LOCKED = [1];

export default class LockedValuesStripSelectExample extends Component {
  @tracked value = [1, 2, 11, 14];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-locked-strip"
      @labelField="fullName"
      @lockedValues={{LOCKED}}
      @maxVisibleChips={{2}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @options={{USER_GROUPS}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.placeholders.choose_groups"
        )
      }}
      @value={{this.value}}
    />
  </template>
}
