import Component from "@glimmer/component";
import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export default class ChatComposerDropdown extends Component {
  @action
  onButtonClick(button, closeFn) {
    // ⚠️ Do not use async/await here ⚠️
    // Safari requires file input clicks to happen synchronously
    // within the user gesture event chain. Using await breaks this
    // chain and prevents the file picker from opening.
    // See: https://webkit.org/blog/13862/the-user-activation-api/
    closeFn();
    button.action();
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
        class={{concatClass
          "chat-composer-dropdown__trigger-btn"
          "btn-flat"
          (if @hasActivePanel "has-active-panel")
        }}
        @title={{i18n "chat.composer.toggle_toolbar"}}
        @icon="plus"
        @disabled={{@isDisabled}}
        @arrow={{true}}
        @placements={{array "top" "bottom"}}
        @identifier="chat-composer-dropdown__menu"
        @modalForMobile={{true}}
        {{on "dblclick" this.doubleClick}}
        ...attributes
        as |menu|
      >
        <ul class="chat-composer-dropdown__list">
          {{#each @buttons as |button|}}
            <li class={{concatClass "chat-composer-dropdown__item" button.id}}>
              <DButton
                @icon={{button.icon}}
                @action={{fn this.onButtonClick button menu.close}}
                @label={{button.label}}
                class={{concatClass
                  "chat-composer-dropdown__action-btn"
                  "btn-transparent"
                  button.id
                }}
              />
            </li>
          {{/each}}
        </ul>
      </DMenu>
    {{/if}}
  </template>
}
