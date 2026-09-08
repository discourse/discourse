import Component from "@glimmer/component";
import { action } from "@ember/object";
import ToolbarPopupMenuOptions from "discourse/components/toolbar-popup-menu-options";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DShortcut from "discourse/ui-kit/d-shortcut";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class ComposerToolbarButtons extends Component {
  // the tab stop must be a rendered button: the leading one may be hidden by its condition
  get firstButton() {
    const { isFirst = true } = this.args;

    if (!isFirst) {
      return false;
    }

    const { context } = this.args.data;

    return this.args.data.groups
      .flatMap((group) => group.buttons ?? [])
      .find((button) => this.isActionable(button) && button.condition(context));
  }

  get rovingButtonBar() {
    return this.args.rovingButtonBar || this.args.data.rovingButtonBar;
  }

  @action
  tabIndex(button) {
    return button === this.firstButton ? 0 : button.tabindex;
  }

  isActionable(button) {
    return button.type !== "separator" && !button.disabled;
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
              @class={{dConcatClass
                button.className
                (if (this.isButtonActive button) "--active")
              }}
              @content={{(button.popupMenu.options)}}
              @context={{@data.context}}
              @header={{button.popupMenu.header}}
              @icon={{button.icon}}
              @onChange={{button.popupMenu.action}}
              @onKeydown={{this.rovingButtonBar}}
              @onOpen={{button.action}}
              @tabindex={{this.tabIndex button}}
              @title={{button.title}}
              @triggerLabel={{button.popupMenu.triggerLabel}}
            />
          {{else}}
            <DShortcut @keys={{button.shortcutKeys}} as |shortcut|>
              <DButton
                aria-keyshortcuts={{shortcut.aria}}
                class={{dConcatClass
                  "toolbar__button"
                  button.className
                  (if (this.isButtonActive button) "--active")
                }}
                rel={{if button.href "noopener noreferrer"}}
                tabindex={{this.tabIndex button}}
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
