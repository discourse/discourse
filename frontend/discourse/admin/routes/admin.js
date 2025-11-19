import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import AdminSearchModal from "discourse/admin/components/modal/admin-search";
import DiscourseRoute from "discourse/routes/discourse";
import { PLATFORM_KEY_MODIFIER } from "discourse/services/keyboard-shortcuts";
import { i18n } from "discourse-i18n";

export default class AdminRoute extends DiscourseRoute {
  @service adminSidebarStateManager;
  @service modal;
  @service keyboardShortcuts;

  @tracked initialSidebarState;

  titleToken() {
    return i18n("admin_title");
  }

  activate() {
    this.keyboardShortcuts.addShortcut(
      `${PLATFORM_KEY_MODIFIER}+/`,
      (event) => this.showAdminSearchModal(event),
      {
        global: true,
      }
    );

    this.adminSidebarStateManager.maybeForceAdminSidebar({
      onlyIfAlreadyActive: false,
    });

    this.controllerFor("application").setProperties({
      showTop: false,
    });
  }

  deactivate(transition) {
    this.controllerFor("application").set("showTop", true);

    this.keyboardShortcuts.unbind({
      [`${PLATFORM_KEY_MODIFIER}+/`]: this.showAdminSearchModal,
    });

    if (!transition?.to.name.startsWith("admin")) {
      this.adminSidebarStateManager.stopForcingAdminSidebar();
    }
  }

  showAdminSearchModal(event) {
    event.preventDefault();
    event.stopPropagation();
    this.modal.show(AdminSearchModal);
  }
}
