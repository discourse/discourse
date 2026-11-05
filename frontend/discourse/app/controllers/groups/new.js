import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class GroupsNewController extends Controller {
  @service router;
  @service site;
  @service groupAutomaticMembersDialog;

  /** @type {boolean | null} */
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
      .then((created) => {
        // Matches the shape `SiteSerializer#groups` sends.
        const fullName = created.full_name || created.name;
        this.site.groups.push({
          id: created.id,
          name: created.name,
          full_name: fullName,
          display_name: fullName,
          flair_url: created.flair_url,
          flair_bg_color: created.flair_bg_color,
          flair_color: created.flair_color,
          automatic: created.automatic,
        });
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
