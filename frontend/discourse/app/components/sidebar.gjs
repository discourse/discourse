import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
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
  WEB_LINK_KINDS,
} from "discourse/lib/sidebar/link-drop";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import { i18n } from "discourse-i18n";

/** Dropping a link here copies it into the sidebar; it does not move anything. */
const copyDropEffect = () => "copy";

export default class Sidebar extends Component {
  @service site;
  @service siteSettings;
  @service currentUser;
  @service modal;
  @service sidebarState;

  /**
   * Whether a drop right now would create a new section.
   *
   * Driven by this element's own drop target rather than by global drag state,
   * which is what makes it go quiet the moment a section underneath claims the
   * drag: only the innermost target is told, so the offer to create a section
   * withdraws exactly when the drop would go into an existing one instead.
   */
  @tracked linkDragActive = false;

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

  /**
   * A drag carrying only text may well turn out to hold nothing droppable, so
   * the offer stays hidden until the drag declares a real URL.
   */
  @action
  trackLinkDrag({ source }) {
    this.linkDragActive = source.containsURLs();
  }

  @action
  clearLinkDrag() {
    this.linkDragActive = false;
  }

  @action
  createSectionFromLink({ source }) {
    this.clearLinkDrag();

    const link = extractDroppedWebLink(source);
    if (!link) {
      return;
    }

    this.modal.show(SidebarSectionForm, {
      model: { link, focusLinkIndex: 0 },
    });
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
    return Boolean(this.#canAcceptLinkDrop) && !source.containsFiles();
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
      {{dDragAndDropExternalTarget
        accepts=WEB_LINK_KINDS
        canDrop=this.canDropLink
        getDropEffect=copyDropEffect
        indicator=false
        onDragEnter=this.trackLinkDrag
        onDrag=this.trackLinkDrag
        onDragLeave=this.clearLinkDrag
        onDrop=this.createSectionFromLink
      }}
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
