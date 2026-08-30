import Component from "@glimmer/component";
import { action } from "@ember/object";
import ToolbarPopupMenuOptions from "discourse/components/toolbar-popup-menu-options";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DShortcut from "discourse/ui-kit/d-shortcut";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class ComposerToolbarButtons extends Component {
  @action
  tabIndex(button) {
    return button === this.firstButton ? 0 : button.tabindex;
  }

  get firstButton() {
    const { isFirst = true } = this.args;
    return (
      isFirst &&
      this.args.data.groups
        .find((group) => group.buttons?.length > 0)
        ?.buttons.filter(this.isActionable)[0]
    );
  }

  isActionable(button) {
    return button.type !== "separator" && !button.disabled;
  }

  get rovingButtonBar() {
    return this.args.rovingButtonBar || this.args.data.rovingButtonBar;
  }

  /** The title with the drawn shortcut appended, when one is shown. */
  @action
  titleFor(button, shortcutLabel) {
    if (!shortcutLabel || button.hideShortcutInTitle) {
      return button.title;
    }
    return `${button.title} (${shortcutLabel})`;
  }

  @action
  isButtonActive(button) {
    const state = this.args.data.context?.textManipulation?.state || {};
    return button.active?.({ state });
  }

  <template>
    {{#each @data.groups key="group" as |group|}}
      {{#each group.buttons key="id" as |button|}}
        {{#if (button.condition @data.context)}}
          {{#if (eq button.type "separator")}}
            <div class="toolbar-separator"></div>
          {{else if button.popupMenu}}
            <ToolbarPopupMenuOptions
              @title={{button.title}}
              @context={{@data.context}}
              @content={{(button.popupMenu.options)}}
              @header={{button.popupMenu.header}}
              @onChange={{button.popupMenu.action}}
              @onOpen={{button.action}}
              @tabindex={{this.tabIndex button}}
              @onKeydown={{this.rovingButtonBar}}
              @icon={{button.icon}}
              @triggerLabel={{button.popupMenu.triggerLabel}}
              @class={{dConcatClass
                button.className
                (if (this.isButtonActive button) "--active")
              }}
            />
          {{else}}
            <DShortcut @keys={{button.shortcutKeys}} as |shortcut|>
              <DButton
                class={{dConcatClass
                  "toolbar__button"
                  button.className
                  (if (this.isButtonActive button) "--active")
                }}
                aria-keyshortcuts={{shortcut.aria}}
                tabindex={{this.tabIndex button}}
                rel={{if button.href "noopener noreferrer"}}
                target={{if button.href "_blank"}}
                @action={{unless button.href button.action}}
                @disabled={{button.disabled}}
                @href={{button.href}}
                @icon={{button.icon}}
                @label={{button.label}}
                @onKeyDown={{this.rovingButtonBar}}
                @preventFocus={{button.preventFocus}}
                @translatedLabel={{button.translatedLabel}}
                @translatedTitle={{this.titleFor button shortcut.label}}
              />
            </DShortcut>
          {{/if}}
        {{/if}}
      {{/each}}
    {{/each}}
  </template>
}
