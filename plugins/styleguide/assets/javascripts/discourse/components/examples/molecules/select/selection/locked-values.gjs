import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { USER_GROUPS } from "../../../../../lib/select-fixtures.js";

/** Admins and moderators always hold access, so they can't be removed. */
const LOCKED = [1, 2];

export default class LockedValuesSelectExample extends Component {
  @tracked value = [1, 2, 11];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @clearable={{true}}
      @identifier="sg-locked-values"
      @labelField="fullName"
      @lockedValues={{LOCKED}}
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
