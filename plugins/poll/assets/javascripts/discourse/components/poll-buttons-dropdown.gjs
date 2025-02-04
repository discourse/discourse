import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
import DMenu from "float-kit/components/d-menu";

const buttonOptionsMap = {
  exportResults: {
    className: "btn-default export-results",
    label: "poll.export-results.label",
    title: "poll.export-results.title",
    icon: "download",
    action: "exportResults",
  },
  showBreakdown: {
    className: "btn-default show-breakdown",
    label: "poll.breakdown.breakdown",
    icon: "chart-pie",
    action: "showBreakdown",
  },
  openPoll: {
    className: "btn-default toggle-status",
    label: "poll.open.label",
    title: "poll.open.title",
    icon: "unlock-keyhole",
    action: "toggleStatus",
  },
  closePoll: {
    className: "btn-default toggle-status",
    label: "poll.close.label",
    title: "poll.close.title",
    icon: "lock",
    action: "toggleStatus",
  },
  showTally: {
    className: "btn-default show-tally",
    label: "poll.show-tally.label",
    title: "poll.show-tally.title",
    icon: "info",
    action: "toggleDisplayMode",
  },
  showPercentage: {
    className: "btn-default show-percentage",
    label: "poll.show-percentage.label",
    title: "poll.show-percentage.title",
    icon: "info",
    action: "toggleDisplayMode",
  },
};

export default class PollButtonsDropdownComponent extends Component {
  @service currentUser;
  @service siteSettings;

  constructor() {
    super(...arguments);
    this.getDropdownButtonState = false;
  }

  @action
  dropDownClick(dropDownAction) {
    this.args.dropDownClick(dropDownAction);
  }

  get getDropdownContent() {
    const contents = [];
    const isAdmin = this.currentUser && this.currentUser.admin;

    const dataExplorerEnabled = this.siteSettings.data_explorer_enabled;
    const exportQueryID = this.args.isRankedChoice
      ? this.siteSettings.poll_export_ranked_choice_data_explorer_query_id
      : this.siteSettings.poll_export_data_explorer_query_id;

    const {
      closed,
      voters,
      isStaff,
      isMe,
      topicArchived,
      groupableUserFields,
      isAutomaticallyClosed,
      availableDisplayMode,
    } = this.args;

    if (availableDisplayMode) {
      const option = { ...buttonOptionsMap[availableDisplayMode] };
      option.id = option.action;
      contents.push(option);
    }

    if (groupableUserFields.length && voters > 0) {
      const option = { ...buttonOptionsMap.showBreakdown };
      option.id = option.action;
      contents.push(option);
    }

    if (isAdmin && dataExplorerEnabled && voters > 0 && exportQueryID) {
      const option = { ...buttonOptionsMap.exportResults };
      option.id = option.action;
      contents.push(option);
    }

    if (this.currentUser && (isMe || isStaff) && !topicArchived) {
      if (closed) {
        if (!isAutomaticallyClosed) {
          const option = { ...buttonOptionsMap.openPoll };
          option.id = option.action;
          contents.push(option);
        }
      } else {
        const option = { ...buttonOptionsMap.closePoll };
        option.id = option.action;
        contents.push(option);
      }
    }

    return contents;
  }

  get showDropdown() {
    return this.getDropdownContent.length > 1;
  }

  get showDropdownAsButton() {
    return this.getDropdownContent.length === 1;
  }

  <template>
    <div class="poll-buttons-dropdown">
      {{#if this.showDropdown}}
        <DMenu class="widget-dropdown-header">
          <:trigger>
            {{icon "gear"}}
          </:trigger>
          <:content>
            <DropdownMenu as |dropdown|>
              {{#each this.getDropdownContent as |content|}}
                <dropdown.item>
                  <DButton
                    class="widget-button {{content.className}}"
                    @icon={{content.icon}}
                    @label={{content.label}}
                    @action={{fn this.dropDownClick content.action}}
                  />
                </dropdown.item>
                <dropdown.divider />
              {{/each}}
            </DropdownMenu>
          </:content>
        </DMenu>
      {{else if this.showDropdownAsButton}}
        <DButton
          class="widget-button {{get this.getDropdownContent '0.className'}}"
          @icon={{get this.getDropdownContent "0.icon"}}
          @label={{get this.getDropdownContent "0.label"}}
          @action={{fn
            this.dropDownClick
            (get this.getDropdownContent "0.action")
          }}
        />
      {{/if}}
    </div>
  </template>
}
