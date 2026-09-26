import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "discourse/lib/service";
import DeferredRender from "discourse/components/deferred-render";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { or } from "discourse/truth-helpers";
import ApiPanels from "./api-panels";
import Footer from "./footer";
import Sections from "./sections";
import AppEventsService from "discourse/services/app-events";
import CurrentUserService from "discourse/services/current-user";
import SiteService from "discourse/services/site";
import SidebarStateService from "discourse/services/sidebar-state";

export default class SidebarHamburgerDropdown extends Component {
  @service(() => AppEventsService) appEvents;
  @service(() => CurrentUserService) currentUser;
  @service(() => SiteService) site;
  @service(() => SidebarStateService) sidebarState;

  get collapsableSections() {
    if (this.site.mobileView || this.site.narrowDesktopView) {
      return true;
    } else {
      return this.args.collapsableSections;
    }
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
    <div class="hamburger-panel">
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
                <Footer />
              </div>
            </DeferredRender>
          </div>
        </div>
      </div>
    </div>
  </template>
}
