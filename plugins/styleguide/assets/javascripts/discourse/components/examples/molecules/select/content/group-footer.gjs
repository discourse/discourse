import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";
import {
  TEAM_MEMBERS,
  teamLabels,
} from "../../../../../lib/select-fixtures.js";

export default class GroupFooterSelectExample extends Component {
  @tracked value = [];

  /** Ends each team with an action that adds its members; the label names the team. */
  @action
  groupFooter(key, options) {
    return selectOption(
      {
        id: `team:${key}`,
        name: i18n("styleguide.sections.select.content.group_footer_label", {
          team: this.teamLabel(key),
        }),
      },
      { onSelect: (control) => control.selectMany(options) }
    );
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
      @labelField="name"
      @multiple={{true}}
      @onChange={{this.onChange}}
      @options={{TEAM_MEMBERS}}
      @texts={{hash
        placeholder=(i18n "styleguide.sections.select.placeholders.find_person")
      }}
      @value={{this.value}}
    >
      <:groupFooter as |record config group|>
        <span class="select-examples__group-footer">
          {{dIcon "user-plus"}}
          {{i18n
            "styleguide.sections.select.content.group_footer_label"
            team=(this.teamLabel group.key)
          }}
        </span>
      </:groupFooter>
    </DSelect>
  </template>
}
