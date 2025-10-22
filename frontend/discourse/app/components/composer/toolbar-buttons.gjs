import Component from "@glimmer/component";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import ToolbarPopupMenuOptions from "discourse/components/toolbar-popup-menu-options";
import concatClass from "discourse/helpers/concat-class";

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
              @onChange={{button.popupMenu.action}}
              @onOpen={{button.action}}
              @tabindex={{this.tabIndex button}}
              @onKeydown={{this.rovingButtonBar}}
              @icon={{button.icon}}
              @class={{concatClass
                button.className
                (if (this.isButtonActive button) "--active")
              }}
            />
          {{else}}
            <DButton
              @href={{button.href}}
              @action={{unless button.href button.action}}
              @translatedTitle={{button.title}}
              @label={{button.label}}
              @translatedLabel={{button.translatedLabel}}
              @disabled={{button.disabled}}
              @icon={{button.icon}}
              @preventFocus={{button.preventFocus}}
              @onKeyDown={{this.rovingButtonBar}}
              aria-keyshortcuts={{button.ariaKeyshortcuts}}
              tabindex={{this.tabIndex button}}
              class={{concatClass
                "toolbar__button"
                button.className
                (if (this.isButtonActive button) "--active")
              }}
              rel={{if button.href "noopener noreferrer"}}
              target={{if button.href "_blank"}}
            />
          {{/if}}
        {{/if}}
      {{/each}}
    {{/each}}
  </template>
}
