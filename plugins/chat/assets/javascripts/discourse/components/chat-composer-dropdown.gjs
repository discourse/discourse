import Component from "@glimmer/component";
import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class ChatComposerDropdown extends Component {
  @action
  async onButtonClick(button, closeFn) {
    // Safari requires file input clicks to happen synchronously
    // within the user gesture event chain. Using await breaks this
    // chain and prevents the file picker from opening.
    // See: https://webkit.org/blog/13862/the-user-activation-api/
    if (button.synchronous) {
      closeFn();
      button.action();
    } else {
      await closeFn();
      await button.action();
    }
  }

  @action
  doubleClick(event) {
    event.preventDefault();

    const uploadButton = this.args.buttons.filter(
      (button) => button.id === "chat-upload-btn" && !button.disabled
    )[0];

    uploadButton?.action?.();
  }

  <template>
    {{#if @buttons.length}}
      <DMenu
        class={{dConcatClass
          "chat-composer-dropdown__trigger-btn"
          "btn-flat"
          (if @hasActivePanel "has-active-panel")
        }}
        ...attributes
        @arrow={{true}}
        @disabled={{@isDisabled}}
        @icon="plus"
        @identifier="chat-composer-dropdown__menu"
        @modalForMobile={{true}}
        @placements={{array "top" "bottom"}}
        @title={{i18n "chat.composer.toggle_toolbar"}}
        {{on "dblclick" this.doubleClick}}
        as |menu|
      >
        <ul class="chat-composer-dropdown__list">
          {{#each @buttons as |button|}}
            <li class={{dConcatClass "chat-composer-dropdown__item" button.id}}>
              <DButton
                class={{dConcatClass
                  "chat-composer-dropdown__action-btn"
                  "btn-transparent"
                  button.id
                }}
                @action={{fn this.onButtonClick button menu.close}}
                @icon={{button.icon}}
                @label={{button.label}}
              />
            </li>
          {{/each}}
        </ul>
      </DMenu>
    {{/if}}
  </template>
}
