import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import ToolbarPopupMenuOptions from "discourse/components/toolbar-popup-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
// import ToolbarPopupMenuOptions from "select-kit/components/toolbar-popup-menu-options";

export default class ComposerToolbarButtons extends Component {
  @action
  tabIndex(button) {
    return button === this.firstButton ? 0 : button.tabindex;
  }

  @action
  getHref(button) {
    return typeof button.href === "function" ? button.href() : button.href;
  }

  @action
  getLabel(button) {
    return typeof button.label === "function" ? button.label() : button.label;
  }

  @action
  getIcon(button) {
    return typeof button.icon === "function" ? button.icon() : button.icon;
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

  <template>
    {{#each @data.groups key="group" as |group|}}
      {{#each group.buttons key="id" as |button|}}
        {{#if (button.condition @data.context)}}
          {{#if (eq button.type "separator")}}
            <div class="toolbar-separator"></div>
          {{else}}
            {{#let
              (this.getHref button) (this.getLabel button) (this.getIcon button)
              as |href label buttonIcon|
            }}
              {{#if href}}
                <a
                  href={{href}}
                  target="_blank"
                  rel="noopener noreferrer"
                  class={{concatClass
                    "btn no-text btn-icon toolbar-link"
                    button.className
                  }}
                  title={{button.title}}
                  tabindex={{this.tabIndex button}}
                  {{on "keydown" this.rovingButtonBar}}
                >
                  {{#if label}}
                    <span title={{label}} class="toolbar-link__label">
                      {{label}}
                    </span>
                  {{/if}}
                  {{#if buttonIcon}}
                    {{icon buttonIcon}}
                  {{/if}}
                </a>
              {{else if button.popupMenu}}

                {{log button}}
                <ToolbarPopupMenuOptions
                  @content={{(button.popupMenu.options)}}
                  @onChange={{button.popupMenu.action}}
                  @onOpen={{fn button.action button}}
                  @tabindex={{this.tabIndex button}}
                  @onKeydown={{this.rovingButtonBar}}
                  @options={{hash icon=buttonIcon focusAfterOnChange=false}}
                  class={{button.className}}
                  @id={{button.id}}
                />
              {{else}}
                <DButton
                  @action={{fn button.action button}}
                  @translatedTitle={{button.title}}
                  @label={{label}}
                  @icon={{buttonIcon}}
                  @preventFocus={{button.preventFocus}}
                  @onKeyDown={{this.rovingButtonBar}}
                  tabindex={{this.tabIndex button}}
                  class={{button.className}}
                />
              {{/if}}
            {{/let}}
          {{/if}}
        {{/if}}
      {{/each}}
    {{/each}}
  </template>
}
