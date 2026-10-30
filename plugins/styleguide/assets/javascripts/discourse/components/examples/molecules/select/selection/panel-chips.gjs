import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { TEAM_MEMBERS } from "../../../../../lib/select-fixtures.js";

export default class PanelChipsSelectExample extends Component {
  @tracked value = [101, 108, 102];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @ariaLabel={{i18n "styleguide.sections.select.panel_chips_label"}}
      @identifier="sg-panel-chips"
      @items={{TEAM_MEMBERS}}
      @labelField="name"
      @multiple={{true}}
      @onChange={{this.onChange}}
      @panelChips={{true}}
      @placeholder={{i18n
        "styleguide.sections.select.placeholders.add_reviewers"
      }}
      @value={{this.value}}
      @variant="button"
    />
  </template>
}
