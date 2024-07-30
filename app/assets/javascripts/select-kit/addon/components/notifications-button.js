import { computed, setProperties } from "@ember/object";
import { allLevels, buttonDetails } from "discourse/lib/notification-levels";
import I18n from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["notifications-button"],
  classNames: ["notifications-button"],
  content: allLevels,
  nameProperty: "key",

  selectKitOptions: {
    autoFilterable: false,
    filterable: false,
    i18nPrefix: "",
    i18nPostfix: "",
  },

  getTitle(key) {
    const { i18nPrefix, i18nPostfix } = this.selectKit.options;
    return I18n.t(`${i18nPrefix}.${key}${i18nPostfix}.title`);
  },

  modifyComponentForRow(_, content) {
    if (content) {
      setProperties(content, {
        title: this.getTitle(content.key),
      });
    }
    return "notifications-button/notifications-button-row";
  },

  modifySelection(content) {
    content = content || {};
    const title = this.getTitle(this.buttonForValue.key);
    setProperties(content, {
      title,
      label: title,
      icon: this.buttonForValue.icon,
    });
    return content;
  },

  buttonForValue: computed("value", function () {
    return buttonDetails(this.value);
  }),
});
