import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { buildPermissionDescription } from "discourse/models/permission-type";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class GroupPermissions extends DiscourseRoute {
  @service router;

  titleToken() {
    return i18n("groups.permissions.title");
  }

  model() {
    let group = this.modelFor("group");

    return ajax(`/g/${group.name}/permissions`)
      .then((permissions) => {
        permissions.forEach((permission) => {
          permission.description = buildPermissionDescription(
            permission.permission_type
          );
        });
        return { permissions };
      })
      .catch(() => {
        this.router.transitionTo("group.members", group);
      });
  }

  setupController(controller, model) {
    this.controllerFor("group-permissions").setProperties({ model });
    this.controllerFor("group").set("showing", "permissions");
  }
}
