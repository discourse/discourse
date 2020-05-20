import I18n from "I18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { allLevels, buttonDetails } from "discourse/lib/notification-levels";
import { computed, setProperties } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["notifications-button"],
  classNames: ["notifications-button"],
  content: allLevels,
  nameProperty: "key",

  selectKitOptions: {
    autoFilterable: false,
    filterable: false,
    i18nPrefix: "",
    i18nPostfix: ""
  },

  modifyComponentForRow() {
    return "notifications-button/notifications-button-row";
  },

  modifySelection(content) {
    content = content || {};
    const { i18nPrefix, i18nPostfix } = this.selectKit.options;
    const title = I18n.t(
      `${i18nPrefix}.${this.buttonForValue.key}${i18nPostfix}.title`
    );
    setProperties(content, {
      title,
      label: title,
      icon: this.buttonForValue.icon
    });
    return content;
  },

  buttonForValue: computed("value", function() {
    return buttonDetails(this.value);
  })
});
