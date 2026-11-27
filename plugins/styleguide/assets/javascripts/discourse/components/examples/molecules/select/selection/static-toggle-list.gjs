import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { EMAIL_TOPICS } from "../../../../../lib/select-fixtures.js";

export default class StaticToggleListSelectExample extends Component {
  @tracked value = ["replies", "mentions"];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-static-toggle"
      @multiple={{true}}
      @onChange={{this.onChange}}
      @options={{EMAIL_TOPICS}}
      @texts={{hash
        ariaLabel=(i18n "styleguide.sections.select.static_toggle_label")
        placeholder=(i18n
          "styleguide.sections.select.placeholders.choose_topics"
        )
      }}
      @value={{this.value}}
      @variant="static"
    />
  </template>
}
