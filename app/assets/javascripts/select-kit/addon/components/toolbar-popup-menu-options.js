import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import I18n from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["toolbar-popup-menu-options"],
  classNames: ["toolbar-popup-menu-options"],

  selectKitOptions: {
    showFullTitle: false,
    filterable: false,
    autoFilterable: false,
    preventHeaderFocus: true,
    customStyle: true,
    titleProperty: "title",
    labelProperty: "label",
  },

  modifyContent(contents) {
    return contents
      .map((content) => {
        if (content.condition) {
          let label;
          if (content.label) {
            label = I18n.t(content.label);
            if (content.shortcut) {
              label += ` <kbd class="shortcut">${PLATFORM_KEY_MODIFIER}+${content.shortcut}</kbd>`;
            }
          }

          return {
            icon: content.icon,
            label,
            title: content.title ? I18n.t(content.title) : null,
            name: content.name,
            id: { name: content.name, action: content.action },
          };
        }
      })
      .filter(Boolean);
  },
});
