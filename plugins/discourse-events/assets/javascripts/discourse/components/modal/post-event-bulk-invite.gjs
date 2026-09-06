import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import GroupSelector from "discourse/components/group-selector";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import ComboBox from "discourse/select-kit/components/combo-box";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import BulkInviteSampleCsvFile from "../bulk-invite-sample-csv-file";
import CsvUploader from "../csv-uploader";

const DEFAULT_ATTENDANCE = "going";

export default class PostEventBulkInvite extends Component {
  @service toasts;

  @tracked flash = null;

  formApi;

  data = { invitees: [{ identifier: null, attendance: DEFAULT_ATTENDANCE }] };

  get bulkInviteStatuses() {
    return [
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
  registerApi(api) {
    this.formApi = api;
  }

  @action
  addInvite(addItemToCollection) {
    const invitees = this.formApi?.get("invitees") ?? [];
    const attendance = invitees.at(-1)?.attendance || DEFAULT_ATTENDANCE;
    addItemToCollection("invitees", { identifier: null, attendance });
  }

  @action
  async removeInvite(remove, index, addItemToCollection) {
    await remove(index);

    // always keep at least one row so the collection never collapses
    if ((this.formApi?.get("invitees") ?? []).length === 0) {
      await addItemToCollection("invitees", {
        identifier: null,
        attendance: DEFAULT_ATTENDANCE,
      });
    }
  }

  @action
  setUserIdentifier(field, selected) {
    field.set(selected[0]);
  }

  @action
  setGroupIdentifier(field, _, groupNames) {
    field.set(groupNames[0]);
  }

  @action
  async sendBulkInvites(data) {
    try {
      const response = await ajax(
        `/discourse-post-event/events/${this.args.model.event.id}/bulk-invite.json`,
        {
          type: "POST",
          dataType: "json",
          contentType: "application/json",
          data: JSON.stringify({ invitees: data.invitees }),
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
  uploadDone() {
    this.args.closeModal();
    this.toasts.success({
      duration: "short",
      data: { message: i18n("discourse_post_event.bulk_invite_modal.success") },
    });
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

          <Form
            @data={{this.data}}
            @onSubmit={{this.sendBulkInvites}}
            @onRegisterApi={{this.registerApi}}
            as |form|
          >
            <form.Collection @name="invitees" as |collection index|>
              <div class="bulk-invite-row">
                <collection.Field
                  class="bulk-invite-identifier-field"
                  @name="identifier"
                  @title={{i18n
                    (if
                      @model.event.isPrivate
                      "discourse_post_event.bulk_invite_modal.group_selector_placeholder"
                      "discourse_post_event.bulk_invite_modal.user_selector_placeholder"
                    )
                  }}
                  @showTitle={{false}}
                  @type="custom"
                  @validation="required"
                  as |field|
                >
                  <field.Control>
                    {{#if @model.event.isPrivate}}
                      <GroupSelector
                        class="bulk-invite-identifier"
                        @single={{true}}
                        @groupFinder={{this.groupFinder}}
                        @groupNames={{field.value}}
                        @placeholderKey="discourse_post_event.bulk_invite_modal.group_selector_placeholder"
                        @onChangeCallback={{fn this.setGroupIdentifier field}}
                      />
                    {{/if}}
                    {{#if @model.event.isPublic}}
                      <EmailGroupUserChooser
                        class="bulk-invite-identifier"
                        @value={{field.value}}
                        @onChange={{fn this.setUserIdentifier field}}
                        @options={{hash
                          maximum=1
                          filterPlaceholder="discourse_post_event.bulk_invite_modal.user_selector_placeholder"
                        }}
                      />
                    {{/if}}
                  </field.Control>
                </collection.Field>

                <collection.Field
                  @name="attendance"
                  @title={{i18n
                    "discourse_post_event.bulk_invite_modal.attendance_label"
                  }}
                  @showTitle={{false}}
                  @type="custom"
                  as |field|
                >
                  <field.Control>
                    <ComboBox
                      class="bulk-invite-attendance"
                      @value={{field.value}}
                      @content={{this.bulkInviteStatuses}}
                      @nameProperty="name"
                      @valueProperty="name"
                      @onChange={{field.set}}
                    />
                  </field.Control>
                </collection.Field>

                <form.Button
                  class="remove-bulk-invite"
                  @icon="trash-can"
                  @action={{fn
                    this.removeInvite
                    collection.remove
                    index
                    form.addItemToCollection
                  }}
                />
              </div>
            </form.Collection>

            <form.Actions class="bulk-invite-actions">
              <form.Submit
                class="send-bulk-invites"
                @label="discourse_post_event.bulk_invite_modal.send_bulk_invites"
              />
              <form.Button
                class="add-bulk-invite"
                @icon="plus"
                @action={{fn this.addInvite form.addItemToCollection}}
              />
            </form.Actions>
          </Form>
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
