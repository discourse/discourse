import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { topics } from "../../../../../lib/select-fixtures.js";

export default class StickySelectExample extends Component {
  @tracked value = null;

  items = topics();

  @action
  onChange(value) {
    this.value = value;
  }

  @action
  specialItems() {
    return [
      {
        id: "suggest",
        name: i18n("styleguide.sections.select.content.sticky_action"),
        sticky: true,
        onSelect: this.suggest,
      },
    ];
  }

  @action
  suggest(control) {
    this.value = this.items[0].id;
    control.close();
  }

  <template>
    <DSelect
      @identifier="sg-content-sticky"
      @items={{this.items}}
      @onChange={{this.onChange}}
      @specialItems={{this.specialItems}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.placeholders.choose_topic"
        )
      }}
      @value={{this.value}}
      @variant="static"
    />
  </template>
}
