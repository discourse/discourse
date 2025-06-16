// // app/assets/javascripts/discourse/app/components/toolbar-popup-menu-options.gjs
// import Component from "@glimmer/component";
// import { tracked } from "@glimmer/tracking";
// import { on } from "@ember/modifier";
// import { action } from "@ember/object";
// import DButton from "discourse/components/d-button";
// import DropdownMenu from "discourse/components/dropdown-menu";
// import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
// import { translateModKey } from "discourse/lib/utilities";
// import { i18n } from "discourse-i18n";
// import DMenu from "float-kit/components/d-menu";
// export default class ToolbarPopupMenuOptions extends Component {
//   @tracked isOpen = false;
//   get menuItems() {
//     return this.args.content
//       ?.map((content) => {
//         if (!content.condition) {
//           return null;
//         }
//         let label;
//         if (content.label) {
//           label = i18n(content.label);
//           if (content.shortcut) {
//             label += ` <kbd class="shortcut">${translateModKey(
//               PLATFORM_KEY_MODIFIER + "+" + content.shortcut
//             )}</kbd>`;
//           }
//         }
//         let title;
//         if (content.title) {
//           title = i18n(content.title);
//           if (content.shortcut) {
//             title += ` (${translateModKey(
//               PLATFORM_KEY_MODIFIER + "+" + content.shortcut
//             )})`;
//           }
//         }
//         let name = content.name;
//         if (!name && content.label) {
//           name = i18n(content.label);
//         }
//         return {
//           icon: content.icon,
//           label,
//           title,
//           name,
//           id: { name: content.name, action: content.action },
//         };
//       })
//       .filter(Boolean);
//   }
//   @action
//   handleSelection(item) {
//     this.isOpen = false;
//     if (typeof this.args.onChange === "function") {
//       this.args.onChange(item.id);
//     }
//   }
//   @action
//   handleOpen() {
//     this.isOpen = true;
//     if (typeof this.args.onOpen === "function") {
//       this.args.onOpen();
//     }
//   }
//   @action
//   handleClose() {
//     this.isOpen = false;
//   }
//   @action
//   handleKeydown(event) {
//     if (typeof this.args.onKeydown === "function") {
//       this.args.onKeydown(event);
//     }
//   }
//   <template>
//     <DMenu
//       @isOpen={{this.isOpen}}
//       @onOpen={{this.handleOpen}}
//       @onClose={{this.handleClose}}
//       class="toolbar-popup-menu-options {{@class}}"
//       tabindex={{@tabindex}}
//       {{on "keydown" this.handleKeydown}}
//     >
//       <:trigger>
//         {{icon @options.icon}}
//         {{!-- <DButton
//           @icon={{@options.icon}}
//           class="btn-flat d-icon-caret-down toolbar-popup-menu-trigger"
//           tabindex={{@tabindex}}
//           aria-expanded={{this.isOpen}}
//         /> --}}
//       </:trigger>
//       <:content>
//         <DropdownMenu as |dropdown|>
//           {{#each this.menuItems as |item|}}
//             <dropdown.item>
//               {{#if item.label}}
//                 {{{item.label}}}
//               {{else}}
//                 {{item.name}}
//               {{/if}}
//             </dropdown.item>
//           {{/each}}
//         </DropdownMenu>
//       </:content>
//     </DMenu>
//   </template>
// }
import Component from "@glimmer/component";
import { array, concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import { translateModKey } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default class ToolbarPopupmenuOptions extends Component {
  dMenu;

  @action
  async onSelect(option) {
    await this.dMenu?.close();
    this.args.onChange?.(option);
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  get convertedContent() {
    return this.args.content.map(convertMenuOption).filter(Boolean);
  }

  <template>
    <DMenu
      @identifier={{concat "toolbar-menu__" @id}}
      @groupIdentifier="toolbar-menu"
      @icon={{@icon}}
      @onRegisterApi={{this.onRegisterApi}}
      @onShow={{@onOpen}}
      @modalForMobile={{true}}
      @placement="bottom"
      @fallbackPlacements={{array "top"}}
      @offset={{5}}
      @onKeydown={{@onKeydown}}
      tabindex="-1"
      class={{concatClass @className}}
    >
      <:trigger>
        {{icon @options.icon}}
      </:trigger>
      <:content>
        <DropdownMenu as |dropdown|>
          {{#each this.convertedContent as |option|}}
            <dropdown.item>
              <DButton
                @translatedLabel={{option.label}}
                @icon={{option.icon}}
                @translatedTitle={{option.title}}
                @action={{fn this.onSelect option}}
              />
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}

export function convertMenuOption(content) {
  if (content.condition) {
    let label;
    if (content.label) {
      label = i18n(content.label);
      if (content.shortcut) {
        label += ` <kbd class="shortcut">${translateModKey(
          PLATFORM_KEY_MODIFIER + "+" + content.shortcut
        )}</kbd>`;
      }
    }

    let title;
    if (content.title) {
      title = i18n(content.title);
      if (content.shortcut) {
        title += ` (${translateModKey(
          PLATFORM_KEY_MODIFIER + "+" + content.shortcut
        )})`;
      }
    }

    let name = content.name;
    if (!name && content.label) {
      name = i18n(content.label);
    }

    return {
      icon: content.icon,
      label,
      title,
      name,
      action: content.action,
      shortcutAction: content.shortcutAction,
    };
  }
}
