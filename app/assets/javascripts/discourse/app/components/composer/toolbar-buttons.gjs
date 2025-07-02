import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import ToolbarPopupMenuOptions from "select-kit/components/toolbar-popup-menu-options";

export default class ComposerToolbarButtons extends Component {
  @action
  tabIndex(button) {
    return button === this.firstButton ? 0 : button.tabindex;
  }

  get firstButton() {
    const { isFirst = true } = this.args;
    return (
      isFirst &&
      this.args.data.groups.find((group) => group.buttons?.length > 0)
        ?.buttons[0]
    );
  }

  get rovingButtonBar() {
    return this.args.rovingButtonBar || this.args.data.rovingButtonBar;
  }

  get textManipulationState() {
    return this.args.data.context?.textManipulation?.state || {};
  }

  @action
  isButtonActive(button) {
    return button.active?.({ state: this.textManipulationState });
  }

  @action
  getButtonIcon(button) {
    if (typeof button.icon === "function") {
      return button.icon({ state: this.textManipulationState });
    }

    return button.icon;
  }

  <template>
    {{#each @data.groups key="group" as |group|}}
      {{#each group.buttons key="id" as |button|}}
        {{#if (button.condition @data.context)}}
          {{#if (eq button.type "separator")}}
            <div class="toolbar-separator"></div>
          {{else if button.popupMenu}}
            <ToolbarPopupMenuOptions
              @content={{(button.popupMenu.options)}}
              @onChange={{button.popupMenu.action}}
              @onOpen={{button.action}}
              @tabindex={{this.tabIndex button}}
              @onKeydown={{this.rovingButtonBar}}
              @options={{hash
                icon=(this.getButtonIcon button)
                focusAfterOnChange=false
              }}
              @textManipulationState={{@context.textManipulation.state}}
              class={{button.className}}
            />
          {{else}}
            <DButton
              @href={{button.href}}
              @action={{unless button.href button.action}}
              @translatedTitle={{button.title}}
              @label={{button.label}}
              @translatedLabel={{button.translatedLabel}}
              @disabled={{button.disabled}}
              @icon={{this.getButtonIcon button}}
              @preventFocus={{button.preventFocus}}
              @onKeyDown={{this.rovingButtonBar}}
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
