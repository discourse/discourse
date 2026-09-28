import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dBoundAvatar from "discourse/ui-kit/helpers/d-bound-avatar";
import { i18n } from "discourse-i18n";
import UserStatusBubble from "./user-dropdown/user-status-bubble";

export default class HeaderProfileToggle extends Component {
  @service currentUser;
  @service mobileTabBar;

  <template>
    <li class="header-dropdown-toggle header-profile-toggle">
      <DButton
        aria-expanded={{if this.mobileTabBar.isProfileMenuOpen "true" "false"}}
        class="icon btn-flat"
        @action={{this.mobileTabBar.toggleProfileMenu}}
        @translatedAriaLabel={{i18n "mobile_tab_bar.profile"}}
        @translatedTitle={{i18n "mobile_tab_bar.profile"}}
      >
        {{dBoundAvatar this.currentUser "medium"}}
        {{#if this.currentUser.status}}
          <UserStatusBubble
            @status={{this.currentUser.status}}
            @timezone={{this.currentUser.user_option.timezone}}
          />
        {{/if}}
      </DButton>
    </li>
  </template>
}
