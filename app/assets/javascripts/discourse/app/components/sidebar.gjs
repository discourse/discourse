import Component from "@glimmer/component";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import ApiPanels from "discourse/components/sidebar/api-panels";
import Footer from "discourse/components/sidebar/footer";
import Sections from "discourse/components/sidebar/sections";
import SwitchPanelButtons from "discourse/components/sidebar/switch-panel-buttons";
import bodyClass from "discourse/helpers/body-class";
import { bind } from "discourse/lib/decorators";

export default class Sidebar extends Component {
  @service appEvents;
  @service site;
  @service siteSettings;
  @service currentUser;
  @service sidebarState;

  constructor() {
    super(...arguments);

    if (this.site.mobileView) {
      document.addEventListener("click", this.collapseSidebar);
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.site.mobileView) {
      document.removeEventListener("click", this.collapseSidebar);
    }
  }

  get showSwitchPanelButtonsOnTop() {
    return this.siteSettings.default_sidebar_switch_panel_position === "top";
  }

  get switchPanelButtons() {
    if (
      !this.sidebarState.displaySwitchPanelButtons ||
      this.sidebarState.panels.length === 1 ||
      !this.currentUser
    ) {
      return [];
    }

    return this.sidebarState.panels.filter(
      (panel) => panel !== this.sidebarState.currentPanel && !panel.hidden
    );
  }

  @bind
  collapseSidebar(event) {
    let shouldCollapseSidebar = false;

    const isClickWithinSidebar = event.composedPath().some((element) => {
      if (
        element?.className !== "sidebar-section-header-caret" &&
        ["A", "BUTTON"].includes(element.nodeName)
      ) {
        shouldCollapseSidebar = true;
        return true;
      }

      return element.className && element.className === "sidebar-wrapper";
    });

    if (shouldCollapseSidebar || !isClickWithinSidebar) {
      this.args.toggleSidebar();
    }
  }

  <template>
    {{bodyClass "has-sidebar-page"}}

    <section id="d-sidebar" class="sidebar-container">
      {{#if this.showSwitchPanelButtonsOnTop}}
        <SwitchPanelButtons @buttons={{this.switchPanelButtons}} />
      {{/if}}

      <PluginOutlet @name="before-sidebar-sections" />

      {{#if this.sidebarState.showMainPanel}}
        <Sections
          @currentUser={{this.currentUser}}
          @collapsableSections={{true}}
          @panel={{this.sidebarState.currentPanel}}
        />
      {{else}}
        <ApiPanels
          @currentUser={{this.currentUser}}
          @collapsableSections={{true}}
        />
      {{/if}}

      <PluginOutlet @name="after-sidebar-sections" />

      {{#unless this.showSwitchPanelButtonsOnTop}}
        <SwitchPanelButtons @buttons={{this.switchPanelButtons}} />
      {{/unless}}

      <Footer />
    </section>
  </template>
}
