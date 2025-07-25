import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class DiscoursePostEventStatus extends Component {
  @service appEvents;
  @service discoursePostEventApi;
  @service siteSettings;

  get eventButtons() {
    return this.siteSettings.event_participation_buttons.split("|");
  }

  get showGoingButton() {
    return !!this.eventButtons.find((button) => button === "going");
  }

  get showInterestedButton() {
    return !!this.eventButtons.find((button) => button === "interested");
  }

  get showNotGoingButton() {
    return !!this.eventButtons.find((button) => button === "not going");
  }

  get canLeave() {
    return this.args.event.watchingInvitee && this.args.event.isPublic;
  }

  get watchingInviteeStatus() {
    return this.args.event.watchingInvitee?.status;
  }

  @action
  async leaveEvent() {
    try {
      const invitee = this.args.event.watchingInvitee;

      await this.discoursePostEventApi.leaveEvent(this.args.event, invitee);

      this.appEvents.trigger("calendar:invitee-left-event", {
        invitee,
        postId: this.args.event.id,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async updateEventAttendance(status) {
    try {
      await this.discoursePostEventApi.updateEventAttendance(this.args.event, {
        status,
      });

      this.appEvents.trigger("calendar:update-invitee-status", {
        status,
        postId: this.args.event.id,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async joinEventWithStatus(status) {
    try {
      await this.discoursePostEventApi.joinEvent(this.args.event, {
        status,
      });

      this.appEvents.trigger("calendar:create-invitee-status", {
        status,
        postId: this.args.event.id,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async changeWatchingInviteeStatus(status) {
    if (this.args.event.watchingInvitee) {
      const currentStatus = this.args.event.watchingInvitee.status;
      if (this.canLeave) {
        if (status === currentStatus) {
          await this.leaveEvent();
        } else {
          await this.updateEventAttendance(status);
        }
      } else {
        if (status === currentStatus) {
          status = null;
        }

        await this.updateEventAttendance(status);
      }
    } else {
      await this.joinEventWithStatus(status);
    }
  }

  <template>
    <section
      class={{concatClass
        "event__section event-actions event-status"
        (if
          this.watchingInviteeStatus
          (concat "status-" this.watchingInviteeStatus)
        )
      }}
    >
      <PluginOutlet
        @name="discourse-post-event-status-buttons"
        @outletArgs={{lazyHash event=@event}}
      >
        {{#if this.showGoingButton}}
          {{#unless @event.minimal}}
            <PluginOutlet
              @name="discourse-post-event-status-going-button"
              @outletArgs={{lazyHash
                event=@event
                markAsGoing=(fn this.changeWatchingInviteeStatus "going")
              }}
            >
              <DButton
                class="going-button"
                @icon="check"
                @label="discourse_post_event.models.invitee.status.going"
                @action={{fn this.changeWatchingInviteeStatus "going"}}
              />
            </PluginOutlet>
          {{/unless}}
        {{/if}}

        {{#if this.showInterestedButton}}
          <PluginOutlet
            @name="discourse-post-event-status-interested-button"
            @outletArgs={{lazyHash
              event=@event
              markAsInterested=(fn
                this.changeWatchingInviteeStatus "interested"
              )
            }}
          >
            <DButton
              class="interested-button"
              @icon="star"
              @label="discourse_post_event.models.invitee.status.interested"
              @action={{fn this.changeWatchingInviteeStatus "interested"}}
            />
          </PluginOutlet>
        {{/if}}

        {{#if this.showNotGoingButton}}
          {{#unless @event.minimal}}
            <PluginOutlet
              @name="discourse-post-event-status-not-going-button"
              @outletArgs={{lazyHash
                event=@event
                markAsNotGoing=(fn this.changeWatchingInviteeStatus "not_going")
              }}
            >
              <DButton
                class="not-going-button"
                @icon="xmark"
                @label="discourse_post_event.models.invitee.status.not_going"
                @action={{fn this.changeWatchingInviteeStatus "not_going"}}
              />
            </PluginOutlet>
          {{/unless}}
        {{/if}}
      </PluginOutlet>
    </section>
  </template>
}
