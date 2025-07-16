import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";

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
}
