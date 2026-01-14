import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
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

  @tracked event;

  setupMessageBus = modifier(() => {
    const path = `/discourse-post-event/${this.event.post.topic.id}`;
    this.messageBus.subscribe(path, async (msg) => {
      const eventData = await this.discoursePostEventApi.event(msg.id);
      this.event.updateFromEvent(eventData);
    });

    return () => this.messageBus.unsubscribe(path);
  });

  getDisplayTime(time) {
    if (this.event.showLocalTime) {
      return moment.tz(time, this.event.timezone || "UTC");
    } else {
      return moment
        .utc(time)
        .tz(this.currentUser?.user_option?.timezone || moment.tz.guess());
    }
  }

  get withDescription() {
    return this.args.withDescription ?? true;
  }

  get startsAtMonth() {
    const displayTime = this.getDisplayTime(this.event.startsAt);
    return displayTime.format("MMM");
  }

  get startsAtDay() {
    const displayTime = this.getDisplayTime(this.event.startsAt);
    return displayTime.format("D");
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

  @bind
  async loadEvent() {
    if (this.event) {
      return this.event;
    }

    if (this.args.event) {
      try {
        this.event = await this.discoursePostEventApi.event(this.args.event.id);
        this.event.startsAt = this.args.event.startsAt;
        this.event.endsAt = this.args.event.endsAt;
      } catch (error) {
        popupAjaxError(error);
      }
    }
  }

  <template>
    <AsyncContent @asyncData={{this.loadEvent}}>
      <:content as |event|>
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
                  @composePrivateMessage={{routeAction "composePrivateMessage"}}
                />

                {{#if @onClose}}
                  <DButton
                    class="btn-default btn-small discourse-post-event-close"
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
                  )
                  Invitees=(component Invitees event=event)
                  Status=(component Status event=event)
                  ChatChannel=(component ChatChannel event=event)
                }}
              >
                <Dates
                  @event={{event}}
                  @expiredAndRecurring={{this.expiredAndRecurring}}
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
      </:content>
      <:loading>
        <div class="discourse-post-event-loader">
          <div class="spinner"></div>
        </div>
      </:loading>
    </AsyncContent>
  </template>
}
