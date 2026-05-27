import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import DMenu from "discourse/float-kit/components/d-menu";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { deferAnonymousAction } from "discourse/lib/anonymous-action";
import DButton from "discourse/ui-kit/d-button";
import DComboButton from "discourse/ui-kit/d-combo-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const GoingDropdown = <template>
  <DDropdownMenu as |dropdown|>
    <dropdown.item
      class={{dConcatClass
        "going-once"
        (if @status.isGoingThisEvent "--selected")
      }}
    >
      <DButton
        class="btn-transparent"
        @icon="check"
        @label="discourse_post_event.models.invitee.this_event"
        @action={{@status.goingThisEvent}}
      />
    </dropdown.item>
    <dropdown.item
      class={{dConcatClass
        "going-all"
        (if @status.isGoingAllFollowing "--selected")
      }}
    >
      <DButton
        class="btn-transparent"
        @icon="arrows-rotate"
        @label="discourse_post_event.models.invitee.this_and_following"
        @action={{@status.goingAllFollowing}}
      />
    </dropdown.item>
    {{#if @status.isGoing}}
      <dropdown.divider />
      <dropdown.item class="going-leave">
        <DButton
          class="btn-transparent --danger"
          @icon="xmark"
          @label="discourse_post_event.models.invitee.leave_event"
          @action={{@status.leaveFromGoingMenu}}
        />
      </dropdown.item>
    {{/if}}
  </DDropdownMenu>
</template>;

export default class DiscoursePostEventStatus extends Component {
  @service appEvents;
  @service currentUser;
  @service discoursePostEventApi;
  @service site;
  @service siteSettings;

  goingMenu = null;

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

  get isGoing() {
    return this.watchingInviteeStatus === "going";
  }

  get isGoingThisEvent() {
    return this.isGoing && !this.args.event.watchingInvitee?.recurring;
  }

  get isGoingAllFollowing() {
    return this.isGoing && this.args.event.watchingInvitee?.recurring;
  }

  get goingButtonDisabled() {
    return this.args.event.atCapacity && !this.isGoing;
  }

  get goingTriggerIcon() {
    return this.isGoingAllFollowing ? "arrows-rotate" : "check";
  }

  get goingTriggerLabel() {
    return i18n(
      this.args.event.atCapacity
        ? "discourse_post_event.models.event.full"
        : "discourse_post_event.models.invitee.status.going"
    );
  }

  @action
  registerGoingMenu(api) {
    this.goingMenu = api;
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
  async goingThisEvent() {
    this.goingMenu?.close();
    await this._setAttendance({ status: "going", recurring: false });
  }

  @action
  async goingAllFollowing() {
    this.goingMenu?.close();
    await this._setAttendance({ status: "going", recurring: true });
  }

  @action
  async leaveFromGoingMenu() {
    this.goingMenu?.close();
    await this.leaveEvent();
  }

  @action
  async changeWatchingInviteeStatus(status) {
    const watching = this.args.event.watchingInvitee;

    if (!watching) {
      await this._setAttendance({ status });
      return;
    }

    if (status === watching.status) {
      await (this.canLeave
        ? this.leaveEvent()
        : this._setAttendance({ status: null }));
      return;
    }

    await this._setAttendance({ status });
  }

  async _setAttendance(payload) {
    if (!this.currentUser) {
      if (!payload.status) {
        return;
      }
      return deferAnonymousAction(this, "rsvp_event", {
        event_id: this.args.event.id,
        status: payload.status,
        recurring: payload.recurring ?? false,
      });
    }

    try {
      const event = this.args.event;
      const data = { status: payload.status, postId: event.id };

      if (event.watchingInvitee) {
        await this.discoursePostEventApi.updateEventAttendance(event, payload);
        this.appEvents.trigger("calendar:update-invitee-status", data);
      } else {
        await this.discoursePostEventApi.joinEvent(event, payload);
        this.appEvents.trigger("calendar:create-invitee-status", data);
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <section
      class={{dConcatClass
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
              {{#if @event.recurrence}}
                {{#if this.site.mobileView}}
                  <DMenu
                    class="btn btn-default going-button"
                    @identifier="discourse-post-event-going-menu"
                    @icon={{this.goingTriggerIcon}}
                    @label={{this.goingTriggerLabel}}
                    @disabled={{this.goingButtonDisabled}}
                    @onRegisterApi={{this.registerGoingMenu}}
                    @modalForMobile={{true}}
                  >
                    <:content>
                      <GoingDropdown @status={{this}} />
                    </:content>
                  </DMenu>
                {{else}}
                  <DComboButton class="going-button --has-menu" as |combo|>
                    <combo.Button
                      class="btn-default"
                      @disabled={{this.goingButtonDisabled}}
                      @icon={{this.goingTriggerIcon}}
                      @label={{if
                        @event.atCapacity
                        "discourse_post_event.models.event.full"
                        "discourse_post_event.models.invitee.status.going"
                      }}
                      @action={{fn this.changeWatchingInviteeStatus "going"}}
                    />
                    <combo.Menu
                      @identifier="discourse-post-event-going-menu"
                      @triggerClass="btn-default"
                      @disabled={{this.goingButtonDisabled}}
                      @onRegisterApi={{this.registerGoingMenu}}
                    >
                      <GoingDropdown @status={{this}} />
                    </combo.Menu>
                  </DComboButton>
                {{/if}}
              {{else}}
                <DButton
                  class="btn-default going-button"
                  @disabled={{this.goingButtonDisabled}}
                  @icon="check"
                  @label={{if
                    @event.atCapacity
                    "discourse_post_event.models.event.full"
                    "discourse_post_event.models.invitee.status.going"
                  }}
                  @action={{fn this.changeWatchingInviteeStatus "going"}}
                />
              {{/if}}
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
              class="btn-default interested-button"
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
                class="btn-default not-going-button"
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
