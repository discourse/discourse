import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import InterfaceColorSelector from "discourse/components/interface-color-selector";
import PluginOutlet from "discourse/components/plugin-outlet";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import DButton from "discourse/ui-kit/d-button";
import CurrentUserService from "discourse/services/current-user";
import ModalService from "discourse/services/modal";
import SiteService from "discourse/services/site";
import SidebarStateService from "discourse/services/sidebar-state";
import InterfaceColorService from "discourse/services/interface-color";

export default class SidebarFooter extends Component {
  @service(() => CurrentUserService) currentUser;
  @service(() => ModalService) modal;
  @service(() => SiteService) site;
  @service(() => SidebarStateService) sidebarState;
  @service(() => InterfaceColorService) interfaceColor;

  get showManageSectionsButton() {
    return this.currentUser && this.sidebarState.isCurrentPanel(MAIN_PANEL);
  }

  @action
  manageSections() {
    this.modal.show(
      () => import("discourse/components/modal/sidebar-section-form")
    );
  }

  @action
  showKeyboardShortcuts() {
    this.modal.show(
      () => import("discourse/components/modal/keyboard-shortcuts-help")
    );
  }

  <template>
    <div class="sidebar-footer-wrapper">
      <div class="sidebar-footer-container">
        <div class="sidebar-footer-actions">
          <PluginOutlet @name="sidebar-footer-actions" />

          {{#if this.interfaceColor.selectorAvailableInSidebar}}
            <InterfaceColorSelector />
          {{/if}}

          {{#if this.showManageSectionsButton}}
            <DButton
              class="btn-flat sidebar-footer-actions-button add-section"
              @action={{this.manageSections}}
              @ariaLabel="sidebar.sections.custom.add"
              @icon="plus"
              @title="sidebar.sections.custom.add"
            />
          {{/if}}

          {{#if this.site.desktopView}}
            <DButton
              class="btn-flat sidebar-footer-actions-button sidebar-footer-actions-keyboard-shortcuts"
              @action={{this.showKeyboardShortcuts}}
              @ariaLabel="keyboard_shortcuts_help.title"
              @icon="keyboard"
              @title="keyboard_shortcuts_help.title"
            />
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
