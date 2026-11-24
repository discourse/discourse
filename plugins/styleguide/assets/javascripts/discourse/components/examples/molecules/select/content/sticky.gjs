import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";
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
  extraOptions() {
    return [
      selectOption(
        {
          id: "suggest",
          name: i18n("styleguide.sections.select.content.sticky_action"),
        },
        { position: "sticky", onSelect: this.suggest }
      ),
    ];
  }

  @action
  suggest(control) {
    this.value = this.items[0].id;
    control.close();
  }

  <template>
    <DSelect
      @extraOptions={{this.extraOptions}}
      @identifier="sg-content-sticky"
      @onChange={{this.onChange}}
      @options={{this.items}}
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
