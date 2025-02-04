import { computed, setProperties } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { allLevels, buttonDetails } from "discourse/lib/notification-levels";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("notifications-button")
@selectKitOptions({
  autoFilterable: false,
  filterable: false,
  i18nPrefix: "",
  i18nPostfix: "",
})
@pluginApiIdentifiers("notifications-button")
export default class NotificationsButton extends DropdownSelectBoxComponent {
  content = allLevels;
  nameProperty = "key";

  getTitle(key) {
    const { i18nPrefix, i18nPostfix } = this.selectKit.options;
    return i18n(`${i18nPrefix}.${key}${i18nPostfix}.title`);
  }

  modifyComponentForRow(_, content) {
    if (content) {
      setProperties(content, {
        title: this.getTitle(content.key),
      });
    }
    return "notifications-button/notifications-button-row";
  }

  modifySelection(content) {
    content = content || {};
    const title = this.getTitle(this.buttonForValue.key);
    setProperties(content, {
      title,
      label: title,
      icon: this.buttonForValue.icon,
    });
    return content;
  }

  @computed("value")
  get buttonForValue() {
    return buttonDetails(this.value);
  }
}
