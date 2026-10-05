import Component from "@glimmer/component";
import { service } from "@ember/service";
import UserMenuProfileTabContent from "discourse/components/user-menu/profile-tab-content";
import { USER_NAV_PANEL } from "discourse/lib/sidebar/panels";
import { not } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

/**
 * Account controls for your own profile panel. With the profile split from
 * notifications, the user menu no longer holds them.
 *
 * @param {boolean} [status] Shows the status controls, which lead the panel,
 * rather than the session controls that close it.
 */
export default class SidebarAccountActions extends Component {
  @service currentUser;
  @service mobileTabBar;
  @service sidebarState;
  @service userNavSidebarStateManager;

  get isVisible() {
    return (
      this.mobileTabBar.splitsProfileMenu &&
      this.sidebarState.currentPanel?.key === USER_NAV_PANEL &&
      this.userNavSidebarStateManager.navController?.model?.id ===
        this.currentUser?.id
    );
  }

  <template>
    {{#if this.isVisible}}
      <div
        class={{dConcatClass "sidebar-account-actions" (if @status "--status")}}
      >
        <UserMenuProfileTabContent
          @closeUserMenu={{this.mobileTabBar.closeMenu}}
          @hideProfileLinks={{true}}
          @hideSessionControls={{@status}}
          @hideStatusControls={{not @status}}
        />
      </div>
    {{/if}}
  </template>
}
