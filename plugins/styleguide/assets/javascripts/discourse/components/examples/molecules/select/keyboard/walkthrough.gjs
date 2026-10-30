import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { USER_GROUPS } from "../../../../../lib/select-fixtures.js";

export default class KeyboardWalkthroughSelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-keyboard-walkthrough"
      @items={{USER_GROUPS}}
      @labelField="fullName"
      @onChange={{this.onChange}}
      @placement="top-start"
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.placeholders.choose_group"
        )
      }}
      @value={{this.value}}
    />
  </template>
}
