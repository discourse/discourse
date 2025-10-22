import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import GroupSelector from "discourse/components/group-selector";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";
import BulkInviteSampleCsvFile from "../bulk-invite-sample-csv-file";
import CsvUploader from "../csv-uploader";

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

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_post_event.bulk_invite_modal.title"}}
      class="post-event-bulk-invite"
      @flash={{this.flash}}
    >
      <:body>
        <div class="bulk-invites">
          <p class="bulk-event-help">
            {{i18n
              (concat
                "discourse_post_event.bulk_invite_modal.description_"
                @model.event.status
              )
            }}
          </p>
          <h3>{{i18n
              "discourse_post_event.bulk_invite_modal.inline_title"
            }}</h3>

          <div class="bulk-invite-rows">
            {{#each this.bulkInvites as |bulkInvite|}}
              <div class="bulk-invite-row">
                {{#if @model.event.isPrivate}}
                  <GroupSelector
                    class="bulk-invite-identifier"
                    @single={{true}}
                    @groupFinder={{this.groupFinder}}
                    @groupNames={{bulkInvite.identifier}}
                    @placeholderKey="discourse_post_event.bulk_invite_modal.group_selector_placeholder"
                    @onChangeCallback={{fn
                      this.updateBulkGroupInviteIdentifier
                      bulkInvite
                    }}
                  />
                {{/if}}
                {{#if @model.event.isPublic}}
                  <EmailGroupUserChooser
                    class="bulk-invite-identifier"
                    @value={{bulkInvite.identifier}}
                    @onChange={{fn this.updateInviteIdentifier bulkInvite}}
                    @options={{hash
                      maximum=1
                      filterPlaceholder="discourse_post_event.bulk_invite_modal.user_selector_placeholder"
                    }}
                  />
                {{/if}}

                <ComboBox
                  class="bulk-invite-attendance"
                  @value={{bulkInvite.attendance}}
                  @content={{this.bulkInviteStatuses}}
                  @nameProperty="name"
                  @valueProperty="name"
                  @onChange={{fn (mut bulkInvite.attendance)}}
                />

                <DButton
                  @icon="trash-can"
                  @action={{fn this.removeBulkInvite bulkInvite}}
                  class="remove-bulk-invite"
                />
              </div>
            {{/each}}
          </div>

          <div class="bulk-invite-actions">
            <DButton
              class="send-bulk-invites btn-primary"
              @label="discourse_post_event.bulk_invite_modal.send_bulk_invites"
              @action={{this.sendBulkInvites}}
              @disabled={{this.bulkInviteDisabled}}
            />
            <DButton
              class="add-bulk-invite"
              @icon="plus"
              @action={{this.addBulkInvite}}
            />
          </div>
        </div>

        <div class="csv-bulk-invites">
          <h3>{{i18n "discourse_post_event.bulk_invite_modal.csv_title"}}</h3>

          <div class="bulk-invite-actions">
            <BulkInviteSampleCsvFile />

            <CsvUploader
              @uploadUrl={{concat
                "/discourse-post-event/events/"
                @model.event.id
                "/csv-bulk-invite"
              }}
              @i18nPrefix="discourse_post_event.bulk_invite_modal"
              @uploadDone={{this.uploadDone}}
            />
          </div>
        </div>
      </:body>
    </DModal>
  </template>
}
