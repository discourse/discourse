import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class GroupsNewController extends Controller {
  @service router;
  @service groupAutomaticMembersDialog;

  saving = null;

  @computed("model.ownerUsernames")
  get splitOwnerUsernames() {
    return this.model?.ownerUsernames && this.model?.ownerUsernames?.length
      ? this.model?.ownerUsernames?.split(",")
      : [];
  }

  @computed("model.usernames")
  get splitUsernames() {
    return this.model?.usernames && this.model?.usernames?.length
      ? this.model?.usernames?.split(",")
      : [];
  }

  @action
  async save() {
    this.set("saving", true);
    const group = this.model;

    const accepted = await this.groupAutomaticMembersDialog.showConfirm(
      group.id,
      group.automatic_membership_email_domains
    );

    if (!accepted) {
      this.set("saving", false);
      return;
    }

    group
      .create()
      .then(() => {
        this.router.transitionTo("group.members", group.name);
      })
      .catch(popupAjaxError)
      .finally(() => this.set("saving", false));
  }

  @action
  updateOwnerUsernames(selected) {
    this.set("model.ownerUsernames", selected.join(","));
  }

  @action
  updateUsernames(selected) {
    this.set("model.usernames", selected.join(","));
  }
}
