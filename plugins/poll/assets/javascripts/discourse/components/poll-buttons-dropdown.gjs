import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

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
    icon: "unlock-alt",
    action: "toggleStatus",
  },
  closePoll: {
    className: "btn-default toggle-status",
    label: "poll.close.label",
    title: "poll.close.title",
    icon: "lock",
    action: "toggleStatus",
  },
};

export default class PollButtonsDropdownComponent extends Component {
  @service currentUser;
  @service siteSettings;
  @tracked getDropdownButtonState;

  constructor() {
    super(...arguments);
    this.getDropdownButtonState = false;
  }
  @action
  toggleDropdownButtonState() {
    this.getDropdownButtonState = !this.getDropdownButtonState;
  }

  @action
  dropDownClick(dropDownAction) {
    this.toggleDropdownButtonState();
    this.args.dropDownClick(dropDownAction);
  }

  get dropDownButtonState() {
    return this.getDropdownButtonState ? "opened" : "closed";
  }

  get getDropdownContent() {
    const contents = [];
    const isAdmin = this.currentUser && this.currentUser.admin;

    const dataExplorerEnabled = this.siteSettings.data_explorer_enabled;
    const exportQueryID = this.siteSettings.poll_export_data_explorer_query_id;

    const closed = this.args.closed;
    const voters = this.args.voters;
    const isStaff = this.args.isStaff;
    const isMe = this.args.isMe;
    const topicArchived = this.args.topicArchived;
    const groupableUserFields = this.args.groupableUserFields;
    const isAutomaticallyClosed = this.args.isAutomaticallyClosed;

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
      <div class="widget-dropdown {{this.dropDownButtonState}}">
        {{#if this.showDropdown}}
          <button
            class="widget-dropdown-header btn btn-default"
            title="poll.dropdown.title"
            {{on "click" this.toggleDropdownButtonState}}
          >
            {{icon "cog"}}
          </button>
        {{/if}}
        <div class="widget-dropdown-body">
          {{#each this.getDropdownContent as |content|}}
            <div class="widget-dropdown-item">
              <button
                class="widget-button {{content.className}}"
                title={{content.title}}
                {{on "click" (fn this.dropDownClick content.action)}}
              >
                {{icon content.icon}}
                <span>{{i18n content.label}}</span>
              </button>
            </div>
          {{/each}}
        </div>
      </div>
    </div>
  </template>
}
