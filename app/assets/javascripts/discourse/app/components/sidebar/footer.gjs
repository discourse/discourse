import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";
import PluginOutlet from "discourse/components/plugin-outlet";
import routeAction from "discourse/helpers/route-action";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";

export default class SidebarFooter extends Component {
  @service capabilities;
  @service currentUser;
  @service modal;
  @service site;
  @service siteSettings;
  @service sidebarState;

  get showManageSectionsButton() {
    return this.currentUser && this.sidebarState.isCurrentPanel(MAIN_PANEL);
  }

  get showToggleMobileButton() {
    return (
      this.site.mobileView ||
      (this.siteSettings.enable_mobile_theme && this.capabilities.touch)
    );
  }

  get showKeyboardShortcutsButton() {
    return this.site.desktopView;
  }

  @action
  manageSections() {
    this.modal.show(SidebarSectionForm);
  }

  <template>
    <div class="sidebar-footer-wrapper">
      <div class="sidebar-footer-container">
        <div class="sidebar-footer-actions">
          <PluginOutlet @name="sidebar-footer-actions" />

          {{#if this.showManageSectionsButton}}
            <DButton
              @icon="plus"
              @action={{this.manageSections}}
              @title="sidebar.sections.custom.add"
              class="btn-flat sidebar-footer-actions-button add-section"
            />
          {{/if}}

          {{#if this.showToggleMobileButton}}
            <DButton
              @action={{routeAction "toggleMobileView"}}
              @title={{if this.site.mobileView "desktop_view" "mobile_view"}}
              @icon={{if this.site.mobileView "desktop" "mobile-alt"}}
              class="btn-flat sidebar-footer-actions-button sidebar-footer-actions-toggle-mobile-view"
            />
          {{/if}}

          {{#if this.showKeyboardShortcutsButton}}
            <DButton
              @action={{routeAction "showKeyboardShortcutsHelp"}}
              @title="keyboard_shortcuts_help.title"
              @icon="keyboard"
              class="btn-flat sidebar-footer-actions-button sidebar-footer-actions-keyboard-shortcuts"
            />
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
