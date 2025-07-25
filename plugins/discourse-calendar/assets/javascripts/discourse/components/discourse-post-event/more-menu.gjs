import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { downloadCalendar } from "discourse/lib/download-calendar";
import { exportEntity } from "discourse/lib/export-csv";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { cook } from "discourse/lib/text";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";
import { buildParams, replaceRaw } from "../../lib/raw-event-helper";
import PostEventBuilder from "../modal/post-event-builder";
import PostEventBulkInvite from "../modal/post-event-bulk-invite";
import PostEventInviteUserOrGroup from "../modal/post-event-invite-user-or-group";
import PostEventInvitees from "../modal/post-event-invitees";

export default class DiscoursePostEventMoreMenu extends Component {
  @service currentUser;
  @service dialog;
  @service discoursePostEventApi;
  @service modal;
  @service router;
  @service siteSettings;
  @service store;

  @tracked isSavingEvent = false;

  get expiredOrClosed() {
    return this.args.event.isExpired || this.args.event.isClosed;
  }

  get canActOnEvent() {
    return this.currentUser && this.args.event.canActOnDiscoursePostEvent;
  }

  get shouldShowParticipants() {
    return applyValueTransformer(
      "discourse-calendar-event-more-menu-should-show-participants",
      this.canActOnEvent && !this.args.isStandaloneEvent,
      {
        event: this.args.event,
      }
    );
  }

  get canInvite() {
    return (
      !this.expiredOrClosed && this.canActOnEvent && this.args.event.isPublic
    );
  }

  get canSeeUpcomingEvents() {
    return !this.args.event.isClosed && this.args.event.recurrence;
  }

  get canBulkInvite() {
    return !this.expiredOrClosed && !this.args.event.isStandalone;
  }

  get canSendPmToCreator() {
    return (
      this.currentUser &&
      this.currentUser.username !== this.args.event.creator.username
    );
  }

  @action
  addToCalendar() {
    this.menuApi.close();

    const event = this.args.event;

    downloadCalendar(
      event.name || event.post.topic.title,
      [
        {
          startsAt: event.startsAt,
          endsAt: event.endsAt,
        },
      ],
      {
        recurrenceRule: event.recurrenceRule,
        location: event.url,
        details: getAbsoluteURL(event.post.url),
      }
    );
  }

  @action
  sendPMToCreator() {
    this.menuApi.close();

    this.args.composePrivateMessage(
      EmberObject.create(this.args.event.creator),
      EmberObject.create(this.args.event.post)
    );
  }

  @action
  upcomingEvents() {
    this.router.transitionTo("discourse-post-event-upcoming-events");
  }

  @action
  registerMenuApi(api) {
    this.menuApi = api;
  }

  @action
  async inviteUserOrGroup() {
    this.menuApi.close();

    try {
      this.modal.show(PostEventInviteUserOrGroup, {
        model: { event: this.args.event },
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  exportPostEvent() {
    this.menuApi.close();

    exportEntity("post_event", {
      name: "post_event",
      id: this.args.event.id,
    });
  }

  @action
  bulkInvite() {
    this.menuApi.close();

    this.modal.show(PostEventBulkInvite, {
      model: { event: this.args.event },
    });
  }

  @action
  async openEvent() {
    this.menuApi.close();

    this.dialog.yesNoConfirm({
      message: i18n("discourse_post_event.builder_modal.confirm_open"),
      didConfirm: async () => {
        this.isSavingEvent = true;

        try {
          const post = await this.store.find("post", this.args.event.id);
          this.args.event.isClosed = false;

          const eventParams = buildParams(
            this.args.event.startsAt,
            this.args.event.endsAt,
            this.args.event,
            this.siteSettings
          );

          const newRaw = replaceRaw(eventParams, post.raw);

          if (newRaw) {
            const props = {
              raw: newRaw,
              edit_reason: i18n("discourse_post_event.edit_reason_opened"),
            };

            const cooked = await cook(newRaw);
            props.cooked = cooked.string;
            await post.save(props);
          }
        } catch (e) {
          popupAjaxError(e);
        } finally {
          this.isSavingEvent = false;
        }
      },
    });
  }

  @action
  async editPostEvent() {
    this.menuApi.close();

    this.modal.show(PostEventBuilder, {
      model: {
        event: this.args.event,
      },
    });
  }

  @action
  showParticipants() {
    this.menuApi.close();

    this.modal.show(PostEventInvitees, {
      model: {
        event: this.args.event,
        title: this.args.event.title,
        extraClass: this.args.event.extraClass,
      },
    });
  }

  @action
  async closeEvent() {
    this.menuApi.close();

    this.dialog.yesNoConfirm({
      message: i18n("discourse_post_event.builder_modal.confirm_close"),
      didConfirm: () => {
        this.isSavingEvent = true;
        return this.store.find("post", this.args.event.id).then((post) => {
          this.args.event.isClosed = true;

          const eventParams = buildParams(
            this.args.event.startsAt,
            this.args.event.endsAt,
            this.args.event,
            this.siteSettings
          );

          const newRaw = replaceRaw(eventParams, post.raw);

          if (newRaw) {
            const props = {
              raw: newRaw,
              edit_reason: i18n("discourse_post_event.edit_reason_closed"),
            };

            return cook(newRaw)
              .then((cooked) => {
                props.cooked = cooked.string;
                return post.save(props);
              })
              .finally(() => {
                this.isSavingEvent = false;
              });
          }
        });
      },
    });
  }

  <template>
    <DMenu
      @identifier="discourse-post-event-more-menu"
      @triggerClass={{concatClass
        "more-dropdown"
        (if this.isSavingEvent "--saving")
      }}
      @icon="ellipsis"
      @onRegisterApi={{this.registerMenuApi}}
    >
      <:content>
        <DropdownMenu as |dropdown|>
          {{#unless this.expiredOrClosed}}
            <dropdown.item class="add-to-calendar">
              <DButton
                @icon="file"
                @label="discourse_post_event.add_to_calendar"
                @action={{this.addToCalendar}}
              />
            </dropdown.item>
          {{/unless}}

          {{#if this.canSendPmToCreator}}
            <dropdown.item class="send-pm-to-creator">
              <DButton
                @icon="envelope"
                class="btn-transparent"
                @translatedLabel={{i18n
                  "discourse_post_event.send_pm_to_creator"
                  (hash username=@event.creator.username)
                }}
                @action={{this.sendPMToCreator}}
              />
            </dropdown.item>
          {{/if}}

          {{#if this.canInvite}}
            <dropdown.item class="invite-user-or-group">
              <DButton
                @icon="user-plus"
                class="btn-transparent"
                @translatedLabel={{i18n "discourse_post_event.invite"}}
                @action={{this.inviteUserOrGroup}}
              />
            </dropdown.item>
          {{/if}}

          {{#if this.canSeeUpcomingEvents}}
            <dropdown.item class="upcoming-events">
              <DButton
                @icon="far-calendar-plus"
                class="btn-transparent"
                @translatedLabel={{i18n
                  "discourse_post_event.upcoming_events.title"
                }}
                @action={{this.upcomingEvents}}
              />
            </dropdown.item>
          {{/if}}

          {{#if this.shouldShowParticipants}}
            <dropdown.item class="show-all-participants">
              <DButton
                @icon="user-group"
                class="btn-transparent"
                @label="discourse_post_event.show_participants"
                @action={{this.showParticipants}}
              />
            </dropdown.item>

            <dropdown.divider />
          {{/if}}
          {{#if this.canActOnEvent}}
            <dropdown.item class="export-event">
              <DButton
                @icon="file-csv"
                class="btn-transparent"
                @label="discourse_post_event.export_event"
                @action={{this.exportPostEvent}}
              />
            </dropdown.item>

            {{#if this.canBulkInvite}}
              <dropdown.item class="bulk-invite">
                <DButton
                  @icon="file-arrow-up"
                  class="btn-transparent"
                  @label="discourse_post_event.bulk_invite"
                  @action={{this.bulkInvite}}
                />
              </dropdown.item>
            {{/if}}

            {{#if @event.isClosed}}
              <dropdown.item class="open-event">
                <DButton
                  @icon="unlock"
                  class="btn-transparent"
                  @label="discourse_post_event.open_event"
                  @action={{this.openEvent}}
                  @disabled={{this.isSavingEvent}}
                />
              </dropdown.item>
            {{else}}
              <dropdown.item class="edit-event">
                <DButton
                  @icon="pencil"
                  class="btn-transparent"
                  @label="discourse_post_event.edit_event"
                  @action={{this.editPostEvent}}
                />
              </dropdown.item>

              {{#unless @event.isExpired}}
                <dropdown.item class="close-event">
                  <DButton
                    @icon="xmark"
                    @label="discourse_post_event.close_event"
                    @action={{this.closeEvent}}
                    @disabled={{this.isSavingEvent}}
                    class="btn-transparent btn-danger"
                  />
                </dropdown.item>
              {{/unless}}
            {{/if}}
          {{/if}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
