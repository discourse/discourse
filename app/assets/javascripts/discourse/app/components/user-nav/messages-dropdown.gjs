import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default class MessagesDropdown extends Component {
  @service currentUser;

  get currentSelection() {
    return this.args.content.find((item) => item.id === this.args.value);
  }

  get showUnreadIcon() {
    return !this.currentUser.sidebarShowCountOfNewItems;
  }

  @action
  onRegisterApi(api) {
    this.menuApi = api;
  }

  @action
  openInbox(id) {
    this.args.onChange(id);
    this.menuApi.close();
  }

  <template>
    <DMenu
      @icon={{this.currentSelection.icon}}
      @label={{this.currentSelection.name}}
      @title={{i18n "user.messages.all"}}
      @identifier="messages-dropdown"
      @onRegisterApi={{this.onRegisterApi}}
    >
      <:trigger>
        {{#if this.currentSelection.showUnreadIcon}}
          {{icon "circle" class="d-icon-d-unread"}}
        {{/if}}
        {{icon "angle-down"}}
      </:trigger>
      <:content>
        <DropdownMenu as |dropdown|>
          {{#each @content as |item|}}
            <dropdown.item>
              <DButton
                @translatedLabel={{item.name}}
                @icon={{item.icon}}
                class={{if
                  (eq this.currentSelection.name item.name)
                  "is-selected"
                }}
                @action={{this.openInbox item.id}}
              >
                {{#if item.showUnreadIcon}}
                  {{icon "circle" class="d-icon-d-unread"}}
                {{/if}}
              </DButton>
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
