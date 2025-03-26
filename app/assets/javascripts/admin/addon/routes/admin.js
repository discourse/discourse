import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import KeyboardShortcuts, {
  PLATFORM_KEY_MODIFIER,
} from "discourse/lib/keyboard-shortcuts";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import AdminSearchModal from "admin/components/modal/admin-search";

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
    if (this.currentUser.use_experimental_admin_search) {
      KeyboardShortcuts.addShortcut(
        `${PLATFORM_KEY_MODIFIER}+/`,
        (event) => this.showAdminSearchModal(event),
        {
          global: true,
        }
      );
    }

    this.adminSidebarStateManager.maybeForceAdminSidebar({
      onlyIfAlreadyActive: false,
    });

    this.controllerFor("application").setProperties({
      showTop: false,
    });
  }

  deactivate(transition) {
    this.controllerFor("application").set("showTop", true);

    if (this.currentUser.use_experimental_admin_search) {
      KeyboardShortcuts.unbind({
        [`${PLATFORM_KEY_MODIFIER}+/`]: this.showAdminSearchModal,
      });
    }

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
