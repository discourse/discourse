import { classNameBindings, classNames } from "@ember-decorators/component";
import Group from "discourse/models/group";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "discourse/select-kit/components/select-kit";
import UserChooserComponent from "discourse/select-kit/components/user-chooser";
import EmailGroupUserChooserFilter from "./email-group-user-chooser-filter.js";
import EmailGroupUserChooserRow from "./email-group-user-chooser-row.gjs";

@classNames("email-group-user-chooser")
@classNameBindings("selectKit.options.fullWidthWrap:full-width-wrap")
@selectKitOptions({
  filterComponent: EmailGroupUserChooserFilter,
  groupsOnly: false,
  excludedGroupIds: null,
  includeEveryone: false,
  lockedValues: null,
  fullWidthWrap: false,
  autoWrap: false,
  prioritizeUserNameOrdering: false,
  prioritizeGroupFullNameOrdering: false,
  excludeGroupNameWhenMatchingFullName: false,
})
@pluginApiIdentifiers(["email-group-user-chooser"])
export default class EmailGroupUserChooser extends UserChooserComponent {
  valueProperty = "id";
  nameProperty = "name";

  modifyComponentForRow() {
    return EmailGroupUserChooserRow;
  }

  deselect(item) {
    if (this.selectKit.options.lockedValues?.includes(this.getValue(item))) {
      return;
    }
    return super.deselect(...arguments);
  }

  validateCreate() {
    if (this.selectKit.options.groupsOnly) {
      return false;
    }
    return super.validateCreate(...arguments);
  }

  search(filter = "") {
    const superPromise = this.selectKit.options.groupsOnly
      ? Group.findAll({
          term: filter,
          ignore_automatic: false,
          include_pseudogroups: true,
          include_everyone: this.selectKit.options.includeEveryone,
        }).then((groups) =>
          groups.filter(
            (group) =>
              (group.id !== 0 || this.selectKit.options.includeEveryone) &&
              !this.selectKit.options.excludedGroupIds?.includes(group.id) &&
              !this.value?.includes(group.name)
          )
        )
      : super.search(...arguments);
    if (!superPromise) {
      return;
    }
    return superPromise.then((results) => {
      if (!results || results.length === 0) {
        return;
      }
      return results.map((item) => {
        const reconstructed = {};
        if (item.username) {
          reconstructed.id = item.username;
          if (item.username.includes("@")) {
            reconstructed.isEmail = true;
          } else {
            reconstructed.isUser = true;
            reconstructed.name = item.name;
            reconstructed.showUserStatus = this.showUserStatus;
          }
        } else if (item.name) {
          reconstructed.id = item.name;
          reconstructed.name = item.full_name || item.name;
          reconstructed.isGroup = true;
        }
        return { ...item, ...reconstructed };
      });
    });
  }
}
