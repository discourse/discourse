import Component from "@glimmer/component";
import { array, concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import { translateModKey } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default class ToolbarPopupmenuOptions extends Component {
  willDestroy() {
    super.willDestroy();
    this.dMenu?.destroy();
  }

  @action
  async onSelect(option) {
    await this.dMenu?.close();
    this.args.onChange?.(option);
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  #convertMenuOption(content) {
    if (content.condition) {
      let label;
      if (content.label) {
        label = content.labelArgs
          ? i18n(content.label, content.labelArgs)
          : i18n(content.label);
        if (content.shortcut) {
          label = htmlSafe(
            `${label} <kbd class="shortcut">${translateModKey(
              PLATFORM_KEY_MODIFIER + "+" + content.shortcut
            )}</kbd>`
          );
        }
      }

      let title = label;
      if (content.title) {
        title = content.titleArgs
          ? i18n(content.title, content.titleArgs)
          : i18n(content.title);
      }

      if (content.shortcut) {
        title += ` (${translateModKey(
          PLATFORM_KEY_MODIFIER + "+" + content.shortcut
        )})`;
      }

      return Object.defineProperties(
        {},
        Object.getOwnPropertyDescriptors({ ...content, label, title })
      );
    }
  }

  get convertedContent() {
    return this.args.content.map(this.#convertMenuOption).filter(Boolean);
  }

  get textManipulationState() {
    return this.args.context?.textManipulation?.state;
  }

  @action
  getActive(option) {
    return option.active?.({ state: this.textManipulationState });
  }

  @action
  getIcon(config) {
    if (typeof config.icon === "function") {
      return config.icon?.({ state: this.textManipulationState });
    }

    return config.icon;
  }

  <template>
    <DMenu
      @identifier={{concat "toolbar-menu__" @class}}
      @groupIdentifier="toolbar-menu"
      @onRegisterApi={{this.onRegisterApi}}
      @onShow={{@onOpen}}
      @modalForMobile={{true}}
      @placement="bottom"
      @fallbackPlacements={{array "top"}}
      @offset={{5}}
      @onKeydown={{@onKeydown}}
      tabindex="-1"
      @class={{concatClass "toolbar__button" @class}}
    >
      <:trigger>
        {{icon (this.getIcon this.args)}}
      </:trigger>
      <:content>
        <DropdownMenu as |dropdown|>
          {{#each this.convertedContent as |option|}}
            <dropdown.item>
              <DButton
                @translatedLabel={{option.label}}
                @translatedTitle={{option.title}}
                @icon={{this.getIcon option}}
                @suffixIcon={{if (this.getActive option) "check"}}
                @action={{fn this.onSelect option}}
                data-name={{option.name}}
              />
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
