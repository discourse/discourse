import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelectGroup from "discourse/ui-kit/select/recipes/groups/d-select-group";
import { i18n } from "discourse-i18n";

const LOCKED = ["staff"];

export default class LockedGroupsSelectExample extends Component {
  @tracked value = ["staff", "trust_level_1"];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelectGroup
      @emit="names"
      @identifier="sg-locked-groups"
      @lockedValues={{LOCKED}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.placeholders.choose_groups"
        )
      }}
      @value={{this.value}}
    />
  </template>
}
