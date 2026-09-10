import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class GroupManageLogsFilter extends Component {
  get label() {
    return i18n(`groups.manage.logs.${this.args.type}`);
  }

  get filterText() {
    return this.args.type === "action"
      ? i18n(`group_histories.actions.${this.args.value}`)
      : this.args.value;
  }

  <template>
    {{#if @value}}
      <DButton
        class="btn-default group-manage-logs-filter"
        @action={{fn @clearFilter @type}}
        @icon="circle-xmark"
        @translatedLabel={{concat this.label ": " this.filterText}}
      />
    {{/if}}
  </template>
}
