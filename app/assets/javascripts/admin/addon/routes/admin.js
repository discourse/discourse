import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import KeyboardShortcuts from "discourse/lib/keyboard-shortcuts";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import AdminPaletteModal from "admin/components/modal/admin-palette";

export default class AdminRoute extends DiscourseRoute {
  @service sidebarState;
  @service siteSettings;
  @service store;
  @service currentUser;
  @service adminSidebarStateManager;
  @service modal;
  @tracked initialSidebarState;

  titleToken() {
    return i18n("admin_title");
  }

  activate() {
    KeyboardShortcuts.addShortcut("meta+/", () => this.showAdminSearchModal(), {
      global: true,
    });

    this.adminSidebarStateManager.maybeForceAdminSidebar({
      onlyIfAlreadyActive: false,
    });

    this.controllerFor("application").setProperties({
      showTop: false,
    });
  }

  deactivate(transition) {
    this.controllerFor("application").set("showTop", true);

    if (this.adminSidebarStateManager.currentUserUsingAdminSidebar) {
      if (!transition?.to.name.startsWith("admin")) {
        this.adminSidebarStateManager.stopForcingAdminSidebar();
      }
    }
  }

  showAdminSearchModal() {
    this.modal.show(AdminPaletteModal);
  }
}
