import I18n from "I18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["toolbar-popup-menu-options"],
  classNames: ["toolbar-popup-menu-options"],

  selectKitOptions: {
    showFullTitle: false,
    filterable: false,
    autoFilterable: false
  },

  modifyContent(contents) {
    return contents
      .map(content => {
        if (content.condition) {
          return {
            icon: content.icon,
            name: I18n.t(content.label),
            id: content.action
          };
        }
      })
      .filter(Boolean);
  }
});
