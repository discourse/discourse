import { service } from "@ember/service";
import Group from "discourse/models/group";
import DiscourseRoute from "discourse/routes/discourse";
import AdminUser from "admin/models/admin-user";

export default class AdminUserIndexRoute extends DiscourseRoute {
  @service siteSettings;

  model() {
    return this.modelFor("adminUser");
  }

  titleToken() {
    return this.currentModel.username;
  }

  async afterModel(model) {
    if (this.currentUser.admin) {
      const groups = await Group.findAll();
      this._availableGroups = groups.filterBy("automatic", false);

      await model.checkEmail();
      await this.currentUser.checkEmail();

      if (this.siteSettings.site_contact_username) {
        this._site_contact = await AdminUser.findByUsername(
          this.siteSettings.site_contact_username
        );
      } else {
        this._site_contact = await AdminUser.find(-1);
      }
      await this._site_contact.checkEmail();
    }
  }

  setupController(controller, model) {
    controller.setProperties({
      originalPrimaryGroupId: model.primary_group_id,
      availableGroups: this._availableGroups,
      customGroupIdsBuffer: model.customGroups.mapBy("id"),
      ssoExternalEmail: null,
      ssoLastPayload: null,
      siteContact: this._site_contact,
      model,
    });
  }
}
