import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { TEAM_MEMBERS, teamLabels } from "../../../../../lib/select-fixtures";

export default class WholePickerSelectExample extends Component {
  @tracked value = [];

  @action
  groupLabel(key) {
    return teamLabels()[key] ?? key;
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-content-picker"
      @items={{TEAM_MEMBERS}}
      @multiple={{true}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @groupBy="team"
      @groupLabel={{this.groupLabel}}
      @labelField="name"
      @placeholder={{i18n
        "styleguide.sections.select.content.picker_placeholder"
      }}
    >
      <:groupHeader as |group|>
        <span class="select-examples__group-header">
          {{dIcon "users"}}
          {{group.label}}
        </span>
      </:groupHeader>
      <:item as |person|>
        <span class="select-examples__row select-examples__row--identity">
          <img class="select-examples__avatar" src={{person.avatar}} alt="" />
          <span class="select-examples__details">
            <span class="select-examples__primary">{{person.name}}</span>
            <span class="select-examples__secondary">
              {{if person.status person.status person.title}}
            </span>
          </span>
        </span>
      </:item>
      <:selection as |person|>
        <span class="select-examples__row select-examples__row--glyph">
          <img
            class="select-examples__avatar --small"
            src={{person.avatar}}
            alt=""
          />
          {{person.name}}
        </span>
      </:selection>
      <:footer as |state|>
        <span class="select-examples__footer-count">
          {{i18n
            "styleguide.sections.select.content.picker_selected"
            count=state.value.length
          }}
        </span>
      </:footer>
    </DSelect>
  </template>
}
