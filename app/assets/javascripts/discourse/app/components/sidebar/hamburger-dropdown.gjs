import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import DeferredRender from "discourse/components/deferred-render";
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
              <div class="sidebar-hamburger-dropdown">
                {{#if
                  (or this.sidebarState.showMainPanel @forceMainSidebarPanel)
                }}
                  <Sections
                    @currentUser={{this.currentUser}}
                    @collapsableSections={{this.collapsableSections}}
                    @panel={{this.sidebarState.currentPanel}}
                    @hideApiSections={{@forceMainSidebarPanel}}
                  />
                {{else}}
                  <ApiPanels
                    @currentUser={{this.currentUser}}
                    @collapsableSections={{this.collapsableSections}}
                  />
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
