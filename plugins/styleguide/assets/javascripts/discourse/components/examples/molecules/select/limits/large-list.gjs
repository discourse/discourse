import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { topics } from "../../../../../lib/select-fixtures.js";

export default class LargeListSelectExample extends Component {
  @tracked value = null;

  items = topics();

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-large-list"
      @items={{this.items}}
      @onChange={{this.onChange}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.placeholders.choose_topic"
        )
      }}
      @value={{this.value}}
    />
  </template>
}
