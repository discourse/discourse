import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

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
      @identifier="messages-dropdown"
      @label={{this.currentSelection.name}}
      @onRegisterApi={{this.onRegisterApi}}
      @title={{i18n "user.messages.all"}}
      @triggerClass="btn-default"
    >
      <:trigger>
        {{#if this.currentSelection.showUnreadIcon}}
          {{dIcon "circle" class="d-icon-d-unread"}}
        {{/if}}
        {{dIcon "angle-down"}}
      </:trigger>
      <:content>
        <DDropdownMenu as |dropdown|>
          {{#each @content as |item|}}
            <dropdown.item>
              <DButton
                class={{if
                  (eq this.currentSelection.name item.name)
                  "is-selected"
                }}
                @action={{this.openInbox item.id}}
                @icon={{item.icon}}
                @translatedLabel={{item.name}}
              >
                {{#if item.showUnreadIcon}}
                  {{dIcon "circle" class="d-icon-d-unread"}}
                {{/if}}
              </DButton>
            </dropdown.item>
          {{/each}}
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
