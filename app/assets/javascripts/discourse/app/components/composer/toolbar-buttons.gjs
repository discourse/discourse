import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import ToolbarPopupMenuOptions from "select-kit/components/toolbar-popup-menu-options";

export default class ComposerToolbarButtons extends Component {
  @action
  tabIndex(button) {
    return button === this.firstButton ? 0 : button.tabindex;
  }

  get firstButton() {
    return (
      this.args.isFirst &&
      this.args.data.groups.find((group) => group.buttons?.length > 0)
        ?.buttons[0]
    );
  }

  <template>
    {{#each @data.groups key="group" as |group|}}
      {{#each group.buttons key="id" as |button|}}
        {{#if (button.condition this.args.data.context)}}
          {{#if button.href}}
            <a
              href={{button.href}}
              target="_blank"
              rel="noopener noreferrer"
              class={{concatClass "btn no-text btn-icon" button.className}}
              title={{button.title}}
              tabindex={{this.tabIndex button}}
            >
              {{icon button.icon}}
            </a>
          {{else if button.popupMenu}}
            <ToolbarPopupMenuOptions
              @content={{(button.popupMenu.options)}}
              @onChange={{button.popupMenu.action}}
              @onOpen={{fn button.action button}}
              @tabindex={{this.tabIndex button}}
              @onKeydown={{@rovingButtonBar}}
              @options={{hash icon=button.icon focusAfterOnChange=false}}
              class={{button.className}}
            />
          {{else if (eq button.type "separator")}}
            <div class="toolbar-separator"></div>
          {{else}}
            <DButton
              @action={{fn button.action button}}
              @translatedTitle={{button.title}}
              @label={{button.label}}
              @icon={{button.icon}}
              @preventFocus={{button.preventFocus}}
              @onKeyDown={{@rovingButtonBar}}
              tabindex={{this.tabIndex button}}
              class={{button.className}}
            />
          {{/if}}
        {{/if}}
      {{/each}}
    {{/each}}
  </template>
}
