import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { USER_GROUPS } from "../../../../../lib/select-fixtures.js";

export default class GroupsSelectExample extends Component {
  @tracked value = [11];

  items = USER_GROUPS.map((group) => ({
    ...group,
    memberLabel: i18n("styleguide.sections.select.showcases.groups.members", {
      count: group.memberCount,
    }),
  }));

  @action
  update(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @iconField="icon"
      @identifier="sg-groups"
      @labelField="fullName"
      @multiple={{true}}
      @onChange={{this.update}}
      @options={{this.items}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.showcases.groups.placeholder"
        )
      }}
      @value={{this.value}}
    >
      <:option as |option|>
        <span class="select-examples__row select-examples__row--glyph">
          <span class="select-examples__primary">{{option.label}}</span>
          {{#if option.record.automatic}}
            <span class="select-showcases__pill">
              {{i18n "styleguide.sections.select.showcases.groups.automatic"}}
            </span>
          {{/if}}
          <span
            class="select-examples__meta"
          >{{option.record.memberLabel}}</span>
        </span>
      </:option>
    </DSelect>
  </template>
}
