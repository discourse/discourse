import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import {
  TEAM_MEMBERS,
  teamLabels,
} from "../../../../../lib/select-fixtures.js";

export default class GroupFooterSelectExample extends Component {
  @tracked value = [];

  /** Ends each team with an action that adds its members; the label names the team. */
  @action
  groupFooter(key, rows) {
    return {
      id: `team:${key}`,
      name: i18n("styleguide.sections.select.content.group_footer_label", {
        team: this.teamLabel(key),
      }),
      onSelect: (control) => control.selectMany(rows),
    };
  }

  @action
  groupHeader(key) {
    return this.teamLabel(key);
  }

  @action
  onChange(value) {
    this.value = value;
  }

  @action
  teamLabel(key) {
    return teamLabels()[key] ?? key;
  }

  <template>
    <DSelect
      @groupBy="team"
      @groupFooter={{this.groupFooter}}
      @groupHeader={{this.groupHeader}}
      @identifier="sg-group-footer"
      @items={{TEAM_MEMBERS}}
      @labelField="name"
      @multiple={{true}}
      @onChange={{this.onChange}}
      @placeholder={{i18n
        "styleguide.sections.select.placeholders.find_person"
      }}
      @value={{this.value}}
    >
      <:groupFooter as |item|>
        <span class="select-examples__group-footer">
          {{dIcon "user-plus"}}
          {{i18n
            "styleguide.sections.select.content.group_footer_label"
            team=(this.teamLabel item.groupKey)
          }}
        </span>
      </:groupFooter>
    </DSelect>
  </template>
}
