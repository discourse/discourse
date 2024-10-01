import { classNames } from "@ember-decorators/component";
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import { translateModKey } from "discourse/lib/utilities";
import I18n from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("toolbar-popup-menu-options")
@selectKitOptions({
  showFullTitle: false,
  filterable: false,
  autoFilterable: false,
  preventHeaderFocus: true,
  customStyle: true,
})
@pluginApiIdentifiers("toolbar-popup-menu-options")
export default class ToolbarPopupMenuOptions extends DropdownSelectBoxComponent {
  modifyContent(contents) {
    return contents
      .map((content) => {
        if (content.condition) {
          let label;
          if (content.label) {
            label = I18n.t(content.label);
            if (content.shortcut) {
              label += ` <kbd class="shortcut">${translateModKey(
                PLATFORM_KEY_MODIFIER + "+" + content.shortcut
              )}</kbd>`;
            }
          }

          let title;
          if (content.title) {
            title = I18n.t(content.title);
            if (content.shortcut) {
              title += ` (${translateModKey(
                PLATFORM_KEY_MODIFIER + "+" + content.shortcut
              )})`;
            }
          }

          let name = content.name;
          if (!name && content.label) {
            name = I18n.t(content.label);
          }

          return {
            icon: content.icon,
            label,
            title,
            name,
            id: { name: content.name, action: content.action },
          };
        }
      })
      .filter(Boolean);
  }
}
