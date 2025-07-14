import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";

@classNames("assigned-to-filter")
export default class AssignedToFilter extends Component {
  static shouldRender(args) {
    return args.additionalFilters;
  }

  @service site;
  @service siteSettings;

  groupIDs = (this.siteSettings.assign_allowed_on_groups || "")
    .split("|")
    .filter(Boolean);
  allowedGroups = this.site.groups
    .filter((group) => this.groupIDs.includes(group.id.toString()))
    .mapBy("name");

  @action
  updateAssignedTo(selected) {
    this.set("outletArgs.additionalFilters.assigned_to", selected.firstObject);
  }

  <template>
    <div class="reviewable-filter discourse-assign-assign-to-filter">
      <label class="filter-label">{{i18n
          "discourse_assign.assigned_to"
        }}</label>

      <EmailGroupUserChooser
        @value={{this.outletArgs.additionalFilters.assigned_to}}
        @onChange={{this.updateAssignedTo}}
        @options={{hash
          maximum=1
          fullWidthWrap=true
          includeGroups=false
          groupMembersOf=this.allowedGroups
        }}
        autocomplete="off"
      />
    </div>
  </template>
}
