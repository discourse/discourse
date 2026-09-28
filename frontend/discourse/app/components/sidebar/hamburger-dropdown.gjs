import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import DeferredRender from "discourse/components/deferred-render";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserMenuProfileTabContent from "discourse/components/user-menu/profile-tab-content";
import lazyHash from "discourse/helpers/lazy-hash";
import { USER_NAV_PANEL } from "discourse/lib/sidebar/panels";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import ApiPanels from "./api-panels";
import Footer from "./footer";
import Sections from "./sections";

export default class SidebarHamburgerDropdown extends Component {
  @service appEvents;
  @service currentUser;
  @service mobileTabBar;
  @service site;
  @service sidebarState;
  @service userNavSidebarStateManager;

  get collapsableSections() {
    if (this.site.mobileView || this.site.narrowDesktopView) {
      return true;
    } else {
      return this.args.collapsableSections;
    }
  }

  // With the tab bar, the header menu only covers notifications, so your own
  // profile menu takes over the account controls.
  // Your profile menu opens from the side of the avatar that opens it
  get opensFromEnd() {
    return (
      this.mobileTabBar.enabled &&
      this.mobileTabBar.menuPanelKey === USER_NAV_PANEL
    );
  }

  get showAccountActions() {
    return (
      this.mobileTabBar.enabled &&
      this.sidebarState.currentPanel?.key === USER_NAV_PANEL &&
      this.userNavSidebarStateManager.navController?.model?.id ===
        this.currentUser?.id
    );
  }

  get menuAction() {
    return this.mobileTabBar.enabled && this.mobileTabBar.menuAction;
  }

  @action
  runMenuAction() {
    const { action: run } = this.menuAction;
    this.mobileTabBar.closeMenu();
    run();
  }

  @action
  triggerRenderedAppEvent() {
    this.appEvents.trigger("sidebar-hamburger-dropdown:rendered");
  }

  @action
  focusFirstLink() {
    schedule("afterRender", () => {
      const firstLink = document.querySelector(".sidebar-hamburger-dropdown a");
      if (firstLink) {
        firstLink.focus();
      }
    });
  }

  <template>
    <div
      class={{dConcatClass "hamburger-panel" (if this.opensFromEnd "--end")}}
    >
      <div
        class="revamped menu-panel drop-down"
        data-max-width="320"
        {{didInsert this.triggerRenderedAppEvent}}
      >
        <div class="panel-body">
          <div class="panel-body-contents">
            <DeferredRender>
              <div
                class="sidebar-hamburger-dropdown"
                {{didInsert this.focusFirstLink}}
              >
                {{#if this.menuAction}}
                  <div class="sidebar-menu-action">
                    <DButton
                      class="btn-primary sidebar-menu-action__button"
                      @action={{this.runMenuAction}}
                      @icon={{this.menuAction.icon}}
                      @translatedLabel={{this.menuAction.label}}
                    />
                  </div>
                {{/if}}
                {{#if this.showAccountActions}}
                  <div class="sidebar-account-actions --status">
                    <UserMenuProfileTabContent
                      @closeUserMenu={{this.mobileTabBar.closeMenu}}
                      @hideProfileLinks={{true}}
                      @hideSessionControls={{true}}
                    />
                  </div>
                {{/if}}
                <PluginOutlet
                  @name="before-sidebar-sections"
                  @outletArgs={{lazyHash
                    toggleNavigationMenu=@toggleNavigationMenu
                  }}
                />
                {{#if
                  (or this.sidebarState.showMainPanel @forceMainSidebarPanel)
                }}
                  <Sections
                    @collapsableSections={{this.collapsableSections}}
                    @currentUser={{this.currentUser}}
                    @hideApiSections={{@forceMainSidebarPanel}}
                    @panel={{this.sidebarState.currentPanel}}
                    @toggleNavigationMenu={{@toggleNavigationMenu}}
                  />
                {{else}}
                  <ApiPanels
                    @collapsableSections={{this.collapsableSections}}
                    @currentUser={{this.currentUser}}
                    @toggleNavigationMenu={{@toggleNavigationMenu}}
                  />
                {{/if}}
                <PluginOutlet @name="after-sidebar-sections" />
                {{#if this.showAccountActions}}
                  <div class="sidebar-account-actions">
                    <UserMenuProfileTabContent
                      @closeUserMenu={{this.mobileTabBar.closeMenu}}
                      @hideProfileLinks={{true}}
                      @hideStatusControls={{true}}
                    />
                  </div>
                {{/if}}
                <Footer />
              </div>
            </DeferredRender>
          </div>
        </div>
      </div>
    </div>
  </template>
}
