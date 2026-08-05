import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";
import PluginOutlet from "discourse/components/plugin-outlet";
import ApiPanels from "discourse/components/sidebar/api-panels";
import Footer from "discourse/components/sidebar/footer";
import Sections from "discourse/components/sidebar/sections";
import SwitchPanelButtons from "discourse/components/sidebar/switch-panel-buttons";
import bodyClass from "discourse/helpers/body-class";
import { bind } from "discourse/lib/decorators";
import {
  extractDroppedWebLink,
  isExplicitWebLinkDrag,
  isWebLinkDrag,
} from "discourse/lib/sidebar/link-drop";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class Sidebar extends Component {
  @service site;
  @service siteSettings;
  @service currentUser;
  @service modal;
  @service sidebarState;

  @tracked linkDragActive = false;
  linkDragDepth = 0;

  constructor() {
    super(...arguments);

    document.addEventListener("dragend", this.resetLinkDrag);

    if (this.site.mobileView) {
      document.addEventListener("click", this.collapseSidebar);
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    document.removeEventListener("dragend", this.resetLinkDrag);

    if (this.site.mobileView) {
      document.removeEventListener("click", this.collapseSidebar);
    }
  }

  get showSwitchPanelButtonsOnTop() {
    return this.siteSettings.default_sidebar_switch_panel_position === "top";
  }

  get canAcceptLinkDrop() {
    return this.currentUser && this.sidebarState.showMainPanel;
  }

  @action
  handleLinkDragEnter(event) {
    if (!this.canAcceptLinkDrop || !isWebLinkDrag(event.dataTransfer)) {
      return;
    }

    event.preventDefault();
    this.linkDragDepth++;
  }

  @action
  handleLinkDragOver(event) {
    // Nested drop targets cancel the event when they own the current destination.
    if (event.defaultPrevented) {
      this.linkDragActive = false;
      return;
    }

    if (!this.canAcceptLinkDrop || !isWebLinkDrag(event.dataTransfer)) {
      return;
    }

    event.preventDefault();
    event.dataTransfer.dropEffect = "copy";
    this.linkDragActive = isExplicitWebLinkDrag(event.dataTransfer);
  }

  @action
  handleLinkDragLeave(event) {
    if (!this.canAcceptLinkDrop || !isWebLinkDrag(event.dataTransfer)) {
      return;
    }

    this.linkDragDepth = Math.max(0, this.linkDragDepth - 1);
    if (this.linkDragDepth === 0) {
      this.linkDragActive = false;
    }
  }

  @bind
  resetLinkDrag() {
    this.linkDragDepth = 0;
    this.linkDragActive = false;
  }

  @action
  handleLinkDrop(event) {
    this.resetLinkDrag();

    if (event.defaultPrevented) {
      return;
    }

    if (!this.canAcceptLinkDrop || !isWebLinkDrag(event.dataTransfer)) {
      return;
    }

    event.preventDefault();

    const link = extractDroppedWebLink(event.dataTransfer);
    if (!link) {
      return;
    }

    this.modal.show(SidebarSectionForm, {
      model: { link, focusLinkIndex: 0 },
    });
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

    <nav
      {{on "dragenter" this.handleLinkDragEnter}}
      {{on "dragover" this.handleLinkDragOver}}
      {{on "dragleave" this.handleLinkDragLeave}}
      {{on "drop" this.handleLinkDrop}}
      id="d-sidebar"
      class={{dConcatClass
        "sidebar-container"
        (if this.linkDragActive "is-link-drag-active")
      }}
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

      {{#if this.linkDragActive}}
        <div class="sidebar-link-drop-target" aria-hidden="true">
          {{dIcon "plus"}}
          <span>{{i18n "sidebar.sections.custom.drop_to_create"}}</span>
        </div>
      {{/if}}

      {{#unless this.showSwitchPanelButtonsOnTop}}
        <SwitchPanelButtons @buttons={{this.switchPanelButtons}} />
      {{/unless}}

      <Footer />
    </nav>
  </template>
}
