import { get } from "@ember/object";
import { service } from "@ember/service";
import AdminUser from "discourse/admin/models/admin-user";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminUserRoute extends DiscourseRoute {
  @service adminSidebarStateManager;
  @service userNavSidebarStateManager;

  serialize(model) {
    return {
      user_id: model.get("id"),
      username: model.get("username").toLowerCase(),
    };
  }

  model(params) {
    return AdminUser.find(get(params, "user_id"));
  }

  afterModel(adminUser) {
    return adminUser.loadDetails().then(function () {
      adminUser.setOriginalTrustLevel();
      return adminUser;
    });
  }

  setupController(controller, model) {
    super.setupController(...arguments);

    // The user nav panel reads both the user being viewed and the tab
    // visibility rules off the `user` controller, and no route populates it
    // here. AdminUser is a User, so those rules resolve the same way they do
    // on a profile. Nothing else on this page wants that controller, so it is
    // only written while the panel is there to read it.
    if (this.userNavSidebarStateManager.enabled) {
      this.controllerFor("user").set("model", model);
    }
  }

  activate() {
    super.activate(...arguments);

    // The parent admin route has already claimed the sidebar by now; this is a
    // user's page, so the user nav takes it back.
    this.userNavSidebarStateManager.captureEntryPoint();
    this.userNavSidebarStateManager.forceUserNavSidebar();
  }

  deactivate(transition) {
    super.deactivate(...arguments);

    this.userNavSidebarStateManager.clearEntryPoint();

    // `routes/admin` only hands the sidebar back when the transition leaves
    // admin altogether, so moving to another admin page has to restore the
    // admin sidebar here — but only when this route took it in the first place.
    if (
      this.userNavSidebarStateManager.enabled &&
      transition?.to?.name?.startsWith("admin")
    ) {
      this.adminSidebarStateManager.maybeForceAdminSidebar({
        onlyIfAlreadyActive: false,
      });
    }
  }
}
