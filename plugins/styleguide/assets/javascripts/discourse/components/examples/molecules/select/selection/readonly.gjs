import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { topicVisibilities } from "../../../../../lib/select-fixtures.js";

export default class ReadonlySelectExample extends Component {
  @tracked value = "members";

  items = topicVisibilities();

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-readonly"
      @items={{this.items}}
      @labelField="title"
      @onChange={{this.onChange}}
      @readonly={{true}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.placeholders.choose_visibility"
        )
      }}
      @value={{this.value}}
      @variant="static"
    />
  </template>
}
