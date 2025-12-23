/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { concat, fn } from "@ember/helper";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

@tagName("")
export default class GroupManageLogsFilter extends Component {
  @computed("type")
  get label() {
    return i18n(`groups.manage.logs.${this.type}`);
  }

  @computed("value", "type")
  get filterText() {
    return this.type === "action" ? i18n(`group_histories.actions.${this.value}`) : this.value;
  }

  <template>
    {{#if this.value}}
      <DButton
        @action={{fn this.clearFilter this.type}}
        @icon="circle-xmark"
        @translatedLabel={{concat this.label ": " this.filterText}}
        class="btn-default group-manage-logs-filter"
      />
    {{/if}}
  </template>
}
