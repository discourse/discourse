import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import InterfaceColorSelector from "discourse/components/interface-color-selector";
import KeyboardShortcutsHelp from "discourse/components/modal/keyboard-shortcuts-help";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";
import PluginOutlet from "discourse/components/plugin-outlet";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import DButton from "discourse/ui-kit/d-button";

export default class SidebarFooter extends Component {
  @service currentUser;
  @service modal;
  @service site;
  @service sidebarState;
  @service interfaceColor;

  get showManageSectionsButton() {
    return this.currentUser && this.sidebarState.isCurrentPanel(MAIN_PANEL);
  }

  @action
  manageSections() {
    this.modal.show(SidebarSectionForm);
  }

  @action
  showKeyboardShortcuts() {
    this.modal.show(KeyboardShortcutsHelp);
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
              @icon="plus"
              @action={{this.manageSections}}
              @title="sidebar.sections.custom.add"
              @ariaLabel="sidebar.sections.custom.add"
              class="btn-flat sidebar-footer-actions-button add-section"
            />
          {{/if}}

          {{#if this.site.desktopView}}
            <DButton
              @action={{this.showKeyboardShortcuts}}
              @title="keyboard_shortcuts_help.title"
              @ariaLabel="keyboard_shortcuts_help.title"
              @icon="keyboard"
              class="btn-flat sidebar-footer-actions-button sidebar-footer-actions-keyboard-shortcuts"
            />
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
