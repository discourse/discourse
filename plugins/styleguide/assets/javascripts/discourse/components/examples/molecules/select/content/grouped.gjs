import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { TEAM_MEMBERS, teamLabels } from "../../../../../lib/select-fixtures";

export default class GroupedSelectExample extends Component {
  @tracked value = null;

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
      @groupBy="team"
      @groupLabel={{this.groupLabel}}
      @identifier="sg-grouped"
      @items={{TEAM_MEMBERS}}
      @labelField="name"
      @onChange={{this.onChange}}
      @placeholder={{i18n
        "styleguide.sections.select.content.grouped_placeholder"
      }}
      @value={{this.value}}
    >
      <:groupHeader as |group|>
        <span class="select-examples__group-header">
          {{dIcon "users"}}
          {{group.label}}
        </span>
      </:groupHeader>
      <:item as |person|>
        <span class="select-examples__row select-examples__row--identity">
          <svg
            aria-hidden="true"
            class="select-examples__avatar"
            style={{person.avatarStyle}}
            viewBox="0 0 48 48"
          >
            <use
              href="/plugins/styleguide/images/avatar.svg#select-avatar"
            ></use>
          </svg>
          <span class="select-examples__details">
            <span class="select-examples__primary">{{person.name}}</span>
            <span class="select-examples__secondary">
              @{{person.username}}
            </span>
          </span>
        </span>
      </:item>
    </DSelect>
  </template>
}
