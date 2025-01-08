import Component from "@glimmer/component";
import { array, fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default class ChatComposerDropdown extends Component {
  @action
  async onButtonClick(button, closeFn) {
    await closeFn({ focusTrigger: false });

    button.action();
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
