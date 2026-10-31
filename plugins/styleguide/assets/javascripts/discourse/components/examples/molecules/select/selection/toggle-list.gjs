import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures.js";

export default class ToggleListSelectExample extends Component {
  @tracked value = ["en", "pt-BR"];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-toggle"
      @items={{LOCALES}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @texts={{hash
        ariaLabel=(i18n "styleguide.sections.select.toggle_label")
        placeholder=(i18n
          "styleguide.sections.select.placeholders.choose_languages"
        )
      }}
      @value={{this.value}}
      @variant="button"
    />
  </template>
}
