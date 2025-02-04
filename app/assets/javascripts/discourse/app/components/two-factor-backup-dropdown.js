import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { selectKitOptions } from "select-kit/components/select-kit";

@classNames("two-factor-backup-dropdown")
@selectKitOptions({
  icon: "wrench",
  showFullTitle: false,
})
export default class TwoFactorBackupDropdown extends DropdownSelectBoxComponent {
  @computed
  get content() {
    const content = [];

    content.push({
      id: "edit",
      icon: "pencil",
      name: i18n("user.second_factor.edit"),
    });

    if (this.secondFactorBackupEnabled) {
      content.push({
        id: "disable",
        icon: "trash-can",
        name: i18n("user.second_factor.disable"),
      });
    }

    return content;
  }

  @action
  onChange(id) {
    switch (id) {
      case "edit":
        this.editSecondFactorBackup();
        break;
      case "disable":
        this.disableSecondFactorBackup();
        break;
    }
  }
}
