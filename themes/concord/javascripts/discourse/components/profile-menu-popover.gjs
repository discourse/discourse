import Component from "@glimmer/component";
import { service } from "@ember/service";
import UserMenuProfileTabContent from "discourse/components/user-menu/profile-tab-content";
import { bind } from "discourse/lib/decorators";

// The user menu's profile tab (status, presence, preferences, log out) on
// its own, opened from the user's name in the user panel. Wrapped in the user
// menu's markup so core's styles for the tab apply.
export default class ProfileMenuPopover extends Component {
  @service router;

  constructor() {
    super(...arguments);
    // The full user menu closes itself on navigation; the tab alone doesn't.
    this.router.on("routeDidChange", this.close);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.router.off("routeDidChange", this.close);
  }

  @bind
  close() {
    this.args.close();
  }

  <template>
    <div class="concord-profile-menu">
      <div class="menu-panel user-menu revamped">
        <div class="panel-body">
          <div class="panel-body-contents">
            <div class="quick-access-panel" id="quick-access-profile">
              {{! Core styles the tab's items by the class the full menu
                  gives them. }}
              <UserMenuProfileTabContent
                @class="user-menu-button-profile"
                @closeUserMenu={{@close}}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </template>
}
