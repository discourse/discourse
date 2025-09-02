import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import AsyncContent from "discourse/components/async-content";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import replaceEmoji from "discourse/helpers/replace-emoji";
import routeAction from "discourse/helpers/route-action";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import loadRRule from "discourse/lib/load-rrule";
import ChatChannel from "./chat-channel";
import Creator from "./creator";
import Dates from "./dates";
import Description from "./description";
import EventStatus from "./event-status";
import Invitees from "./invitees";
import Location from "./location";
import MoreMenu from "./more-menu";
import Status from "./status";
import Url from "./url";

const StatusSeparator = <template>
  <span class="separator">·</span>
</template>;

const InfoSection = <template>
  <section class="event__section" ...attributes>
    {{#if @icon}}
      {{icon @icon}}
    {{/if}}

    {{yield}}
  </section>
</template>;

export default class DiscoursePostEvent extends Component {
  @service currentUser;
  @service discoursePostEventApi;
  @service messageBus;

  @tracked event = this.args.event;
  @tracked rrule;

  setupMessageBus = modifier(() => {
    const path = `/discourse-post-event/${this.event.post.topic.id}`;
    this.messageBus.subscribe(path, async (msg) => {
      const eventData = await this.discoursePostEventApi.event(msg.id);
      this.event.updateFromEvent(eventData);
    });

    return () => this.messageBus.unsubscribe(path);
  });

  constructor() {
    super(...arguments);

    this.loadRRule();
  }

  get currentEventEnd() {
    if (!this.event.duration) {
      return this.currentEventStart.clone().add(1, "hour");
    }

    const [hours, minutes, seconds] = this.event.duration
      .split(":")
      .map(Number);
    const totalSeconds = hours * 3600 + minutes * 60 + seconds;

    return this.currentEventStart.clone().add(totalSeconds, "seconds");
  }

  get currentEventStart() {
    let start = this.event.startsAt;

    if (this.event.rrule) {
      if (this.args.currentEventStart) {
        if (this.event.showLocalTime && this.event.timezone) {
          const fullCalendarDate = this.args.currentEventStart;
          const fullCalendarMoment = moment(fullCalendarDate);
          const originalEventMoment = moment.tz(
            this.event.startsAt,
            this.event.timezone
          );

          // Create a new moment with the FullCalendar date but the original event time
          const eventMoment = moment.tz(
            [
              fullCalendarMoment.year(),
              fullCalendarMoment.month(),
              fullCalendarMoment.date(),
              originalEventMoment.hour(),
              originalEventMoment.minute(),
              originalEventMoment.second(),
            ],
            this.event.timezone
          );

          start = eventMoment;
        } else {
          start = this.args.currentEventStart;
        }
      } else {
        const { rrulestr } = this.rrule;
        const rule = rrulestr(this.event.rrule);
        const dtstart = moment().subtract(23, "hours").toDate();
        start = rule.after(dtstart);
      }
    }

    let result;
    if (this.event.showLocalTime) {
      if (this.event.rrule) {
        // If start is already a moment object, use it directly
        if (moment.isMoment(start)) {
          result = start;
        } else {
          result = moment.utc(start).tz(this.event.timezone || "UTC", true);
        }
      } else {
        result = moment.tz(start, this.event.timezone || "UTC");
      }
    } else {
      result = moment
        .utc(start)
        .tz(this.currentUser?.user_option?.timezone || moment.tz.guess());
    }

    return result;
  }

  get withDescription() {
    return this.args.withDescription ?? true;
  }

  get startsAtMonth() {
    return this.currentEventStart.format("MMM");
  }

  get startsAtDay() {
    return this.currentEventStart.format("D");
  }

  get eventName() {
    return this.event.name || this.event.post.topic.title;
  }

  get isPublicEvent() {
    return this.event.status === "public";
  }

  get isStandaloneEvent() {
    return this.event.status === "standalone";
  }

  get canActOnEvent() {
    return this.currentUser && this.event.can_act_on_discourse_post_event;
  }

  get watchingInviteeStatus() {
    return this.event.watchingInvitee?.status;
  }

  get expiredAndRecurring() {
    return this.event.isExpired && this.event.recurrence;
  }

  @action
  async loadRRule() {
    this.rrule = await loadRRule();
  }

  @bind
  async loadEvent() {
    if (this.event) {
      return this.event;
    }

    if (this.args.eventId) {
      try {
        return (this.event = await this.discoursePostEventApi.event(
          this.args.eventId
        ));
      } catch (error) {
        popupAjaxError(error);
      }
    }
  }

  <template>
    <AsyncContent @asyncData={{this.loadEvent}}>
      <:content as |event|>
        {{#if this.rrule}}
          <div class="discourse-post-event">
            <div class="discourse-post-event-widget">
              {{#if event}}
                <header class="event-header" {{this.setupMessageBus}}>
                  <div class="event-date">
                    <div class="month">
                      {{#if this.expiredAndRecurring}}
                        -
                      {{else}}
                        {{this.startsAtMonth}}
                      {{/if}}
                    </div>
                    <div class="day">
                      {{#if this.expiredAndRecurring}}
                        -
                      {{else}}
                        {{this.startsAtDay}}
                      {{/if}}
                    </div>
                  </div>
                  <div class="event-info">
                    <span class="name">
                      {{#if @linkToPost}}
                        <a
                          href={{event.post.url}}
                          rel="noopener noreferrer"
                        >{{replaceEmoji this.eventName}}</a>
                      {{else}}
                        {{replaceEmoji this.eventName}}
                      {{/if}}
                    </span>
                    <div class="status-and-creators">
                      <PluginOutlet
                        @name="discourse-post-event-status-and-creators"
                        @outletArgs={{lazyHash
                          event=event
                          Separator=StatusSeparator
                          Status=(component EventStatus event=event)
                          Creator=(component Creator user=event.creator)
                        }}
                      >
                        <EventStatus @event={{event}} />
                        <StatusSeparator />
                        <Creator @user={{event.creator}} />
                      </PluginOutlet>
                    </div>
                  </div>

                  <MoreMenu
                    @event={{event}}
                    @isStandaloneEvent={{this.isStandaloneEvent}}
                    @composePrivateMessage={{routeAction
                      "composePrivateMessage"
                    }}
                  />

                  {{#if @onClose}}
                    <DButton
                      class="btn-small discourse-post-event-close"
                      @icon="xmark"
                      @action={{@onClose}}
                    />
                  {{/if}}
                </header>

                <PluginOutlet
                  @name="discourse-post-event-info"
                  @outletArgs={{lazyHash
                    event=event
                    Section=(component InfoSection event=event)
                    Url=(component Url url=event.url)
                    Description=(component
                      Description description=event.description
                    )
                    Location=(component Location location=event.location)
                    Dates=(component
                      Dates
                      event=event
                      expiredAndRecurring=this.expiredAndRecurring
                      currentEventStart=this.currentEventStart
                      currentEventEnd=this.currentEventEnd
                    )
                    Invitees=(component Invitees event=event)
                    Status=(component Status event=event)
                    ChatChannel=(component ChatChannel event=event)
                  }}
                >
                  <Dates
                    @event={{event}}
                    @expiredAndRecurring={{this.expiredAndRecurring}}
                    @currentEventStart={{this.currentEventStart}}
                    @currentEventEnd={{this.currentEventEnd}}
                  />
                  <Location @location={{event.location}} />
                  <Url @url={{event.url}} />
                  <ChatChannel @event={{event}} />
                  <Invitees @event={{event}} />

                  {{#if this.withDescription}}
                    <Description @description={{event.description}} />
                  {{/if}}

                  {{#if @event.canUpdateAttendance}}
                    <Status @event={{event}} />
                  {{/if}}
                </PluginOutlet>
              {{/if}}
            </div>
          </div>
        {{/if}}
      </:content>
      <:loading>
        <div class="discourse-post-event-loader">
          <div class="spinner"></div>
        </div>
      </:loading>
    </AsyncContent>
  </template>
}
