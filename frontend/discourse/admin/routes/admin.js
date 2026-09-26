import { tracked } from "@glimmer/tracking";
import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";
import { PLATFORM_KEY_MODIFIER } from "discourse/services/keyboard-shortcuts";
import { i18n } from "discourse-i18n";
import AdminSidebarStateManagerService from "discourse/admin/services/admin-sidebar-state-manager";
import ModalService from "discourse/services/modal";
import KeyboardShortcutsService from "discourse/services/keyboard-shortcuts";

export default class AdminRoute extends DiscourseRoute {
  @service(() => AdminSidebarStateManagerService) adminSidebarStateManager;
  @service(() => ModalService) modal;
  @service(() => KeyboardShortcutsService) keyboardShortcuts;

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
    this.modal.show(
      () => import("discourse/admin/components/modal/admin-search")
    );
  }
}
