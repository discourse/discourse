import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { USER_GROUPS } from "../../../../../lib/select-fixtures";

export default class GroupsSelectExample extends Component {
  @tracked value = [11];

  items = USER_GROUPS.map((group) => ({
    ...group,
    memberLabel: i18n("styleguide.sections.select.pickers.groups.members", {
      count: group.memberCount,
    }),
  }));

  @action
  update(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-groups"
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.update}}
      @multiple={{true}}
      @labelField="fullName"
      @placeholder={{i18n
        "styleguide.sections.select.pickers.groups.placeholder"
      }}
    >
      <:item as |group|>
        <span class="select-examples__row select-examples__row--glyph">
          {{dIcon group.icon}}
          <span class="select-examples__primary">{{group.fullName}}</span>
          {{#if group.automatic}}
            <span class="select-showcases__pill">
              {{i18n "styleguide.sections.select.pickers.groups.automatic"}}
            </span>
          {{/if}}
          <span class="select-examples__meta">{{group.memberLabel}}</span>
        </span>
      </:item>
    </DSelect>
  </template>
}
