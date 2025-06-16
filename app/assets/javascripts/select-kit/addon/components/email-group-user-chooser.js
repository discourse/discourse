import { classNameBindings, classNames } from "@ember-decorators/component";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";
import UserChooserComponent from "select-kit/components/user-chooser";
import EmailGroupUserChooserFilter from "./email-group-user-chooser-filter";
import EmailGroupUserChooserRow from "./email-group-user-chooser-row";

@classNames("email-group-user-chooser")
@classNameBindings("selectKit.options.fullWidthWrap:full-width-wrap")
@selectKitOptions({
  filterComponent: EmailGroupUserChooserFilter,
  fullWidthWrap: false,
  autoWrap: false,
})
@pluginApiIdentifiers(["email-group-user-chooser"])
export default class EmailGroupUserChooser extends UserChooserComponent {
  valueProperty = "id";
  nameProperty = "name";

  modifyComponentForRow() {
    return EmailGroupUserChooserRow;
  }

  search() {
    const superPromise = super.search(...arguments);
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
          reconstructed.name = item.full_name;
          reconstructed.isGroup = true;
        }
        return { ...item, ...reconstructed };
      });
    });
  }
}
