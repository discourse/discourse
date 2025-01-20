import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import DeferredRender from "discourse/components/deferred-render";
import PluginOutlet from "discourse/components/plugin-outlet";
import ApiPanels from "./api-panels";
import Footer from "./footer";
import Sections from "./sections";

export default class SidebarHamburgerDropdown extends Component {
  @service appEvents;
  @service currentUser;
  @service site;
  @service siteSettings;
  @service sidebarState;

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

  get collapsableSections() {
    if (
      this.siteSettings.navigation_menu === "header dropdown" &&
      !this.args.collapsableSections
    ) {
      return this.site.mobileView || this.site.narrowDesktopView;
    } else {
      this.args.collapsableSections;
    }
  }

  <template>
    <div class="hamburger-panel">
      <div
        {{didInsert this.triggerRenderedAppEvent}}
        data-max-width="320"
        class="revamped menu-panel drop-down"
      >
        <div class="panel-body">
          <div class="panel-body-contents">
            <DeferredRender>
              <div
                class="sidebar-hamburger-dropdown"
                {{didInsert this.focusFirstLink}}
              >
                <PluginOutlet @name="before-sidebar-sections" />
                {{#if
                  (or this.sidebarState.showMainPanel @forceMainSidebarPanel)
                }}
                  <Sections
                    @currentUser={{this.currentUser}}
                    @collapsableSections={{this.collapsableSections}}
                    @panel={{this.sidebarState.currentPanel}}
                    @hideApiSections={{@forceMainSidebarPanel}}
                    @toggleNavigationMenu={{@toggleNavigationMenu}}
                  />
                {{else}}
                  <ApiPanels
                    @currentUser={{this.currentUser}}
                    @collapsableSections={{this.collapsableSections}}
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
