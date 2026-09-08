import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import ApiPanels from "discourse/components/sidebar/api-panels";
import Footer from "discourse/components/sidebar/footer";
import Sections from "discourse/components/sidebar/sections";
import SwitchPanelButtons from "discourse/components/sidebar/switch-panel-buttons";
import bodyClass from "discourse/helpers/body-class";
import { bind } from "discourse/lib/decorators";
import {
  WEB_LINK_ADOPTION,
  WEB_LINK_KINDS,
  webLinkPayload,
} from "discourse/lib/sidebar/link-drop";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

export default class Sidebar extends Component {
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

  get #canAcceptLinkDrop() {
    return this.currentUser && this.sidebarState.showMainPanel;
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

  /**
   * The target stays registered whatever the sidebar is showing, and refuses
   * here instead, so a panel switch cannot leave a half-built registration
   * behind mid-drag.
   *
   * Files are their own drag with their own destinations, and this one only
   * knows what to do with a URL.
   */
  @action
  canDropLink({ source }) {
    return (
      Boolean(this.#canAcceptLinkDrop) &&
      !webLinkPayload(source).containsFiles()
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

    {{! A drop suppressor, not a destination: dragging a link over the sidebar
        is invited, so a drop that misses the real targets inside must cancel
        with a no-drop cursor rather than take the browser default of
        navigating to the dropped URL. No callbacks, so nothing can mistake it
        for handling the drop. }}
    <nav
      {{dDragAndDropExternalTarget
        accepts=WEB_LINK_KINDS
        canDrop=this.canDropLink
        dropEffect="none"
        indicator=false
      }}
      {{! The same suppression, for a link the browser started dragging from
          this page rather than from outside the window. }}
      {{dDragAndDropTarget
        adopts=WEB_LINK_ADOPTION
        canDrop=this.canDropLink
        dropEffect="none"
        indicator=false
      }}
      id="d-sidebar"
      class="sidebar-container"
      aria-label={{i18n "sidebar.title"}}
    >
      {{#if this.showSwitchPanelButtonsOnTop}}
        <SwitchPanelButtons @buttons={{this.switchPanelButtons}} />
      {{/if}}

      <PluginOutlet @name="before-sidebar-sections" />

      {{#if this.sidebarState.showMainPanel}}
        <Sections
          @currentUser={{this.currentUser}}
          @collapsableSections={{true}}
          @enableLinkDrop={{true}}
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
    </nav>
  </template>
}
