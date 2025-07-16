import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import { i18n } from "discourse-i18n";

export default class PostEventBulkInvite extends Component {
  @service dialog;

  @tracked
  bulkInvites = new TrackedArray([
    EmberObject.create({ identifier: null, attendance: "unknown" }),
  ]);
  @tracked bulkInviteDisabled = true;
  @tracked flash = null;

  get bulkInviteStatuses() {
    return [
      {
        label: i18n("discourse_post_event.models.invitee.status.unknown"),
        name: "unknown",
      },
      {
        label: i18n("discourse_post_event.models.invitee.status.going"),
        name: "going",
      },
      {
        label: i18n("discourse_post_event.models.invitee.status.not_going"),
        name: "not_going",
      },
      {
        label: i18n("discourse_post_event.models.invitee.status.interested"),
        name: "interested",
      },
    ];
  }

  @action
  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: true });
  }

  @action
  setBulkInviteDisabled() {
    this.bulkInviteDisabled =
      this.bulkInvites.filter((x) => isPresent(x.identifier)).length === 0;
  }

  @action
  async sendBulkInvites() {
    try {
      const response = await ajax(
        `/discourse-post-event/events/${this.args.model.event.id}/bulk-invite.json`,
        {
          type: "POST",
          dataType: "json",
          contentType: "application/json",
          data: JSON.stringify({
            invitees: this.bulkInvites.filter((x) => isPresent(x.identifier)),
          }),
        }
      );

      if (response.success) {
        this.args.closeModal();
      }
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  @action
  removeBulkInvite(bulkInvite) {
    this.bulkInvites.removeObject(bulkInvite);

    if (!this.bulkInvites.length) {
      this.bulkInvites.pushObject(
        EmberObject.create({ identifier: null, attendance: "unknown" })
      );
    }
  }

  @action
  addBulkInvite() {
    const attendance =
      this.bulkInvites[this.bulkInvites.length - 1]?.attendance || "unknown";
    this.bulkInvites.pushObject(
      EmberObject.create({ identifier: null, attendance })
    );
  }

  @action
  async uploadDone() {
    await this.dialog.alert(
      i18n("discourse_post_event.bulk_invite_modal.success")
    );
    this.args.closeModal();
  }

  @action
  updateInviteIdentifier(bulkInvite, selected) {
    bulkInvite.set("identifier", selected[0]);
    this.setBulkInviteDisabled();
  }

  @action
  updateBulkGroupInviteIdentifier(bulkInvite, _, groupNames) {
    bulkInvite.set("identifier", groupNames[0]);
    this.setBulkInviteDisabled();
  }
}
