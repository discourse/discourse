import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import moment from "moment";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import { recurrenceContext, recurrenceRef } from "../../lib/event-recurrence";
import ChatChannel from "./chat-channel";
import Creator from "./creator";
import Dates from "./dates";
import Description from "./description";
import EventStatus from "./event-status";
import Image from "./image";
import Invitees from "./invitees";
import Livestream from "./livestream";
import DiscoursePostEventLocation from "./location";
import MoreMenu from "./more-menu";
import Status from "./status";
import Url from "./url";

const StatusSeparator = <template>
  <span class="separator">·</span>
</template>;

const InfoSection = <template>
  <section class="event__section" ...attributes>
    {{#if @icon}}
      {{dIcon @icon}}
    {{/if}}

    {{yield}}
  </section>
</template>;

const CreatorPlaceholder = <template>
  <span
    class="event__placeholder event__placeholder--text placeholder-animation"
  ></span>
</template>;

const InviteesPlaceholder = <template>
  <section class="event__section event-invitees event-invitees--loading">
    {{dIcon "users"}}
    <ul class="event-invitees-avatars">
      <li
        class="event__placeholder event__placeholder--avatar placeholder-animation"
      ></li>
      <li
        class="event__placeholder event__placeholder--avatar placeholder-animation"
      ></li>
      <li
        class="event__placeholder event__placeholder--avatar placeholder-animation"
      ></li>
    </ul>
  </section>
</template>;

const StatusPlaceholder = <template>
  <section
    class="event__section event-actions event-status event-status--loading"
  >
    <span
      class="event__placeholder event__placeholder--button placeholder-animation"
    ></span>
    <span
      class="event__placeholder event__placeholder--button placeholder-animation"
    ></span>
    <span
      class="event__placeholder event__placeholder--button placeholder-animation"
    ></span>
  </section>
</template>;

export default class DiscoursePostEvent extends Component {
  @service currentUser;
  @service discoursePostEventApi;
  @service messageBus;
  @service siteSettings;

  @tracked fetchedEvent;
  @tracked isLoading = false;

  setupMessageBus = modifier(() => {
    const topicId = this.event?.post?.topic?.id;
    if (!topicId) {
      return;
    }

    const path = `/discourse-post-event/${topicId}`;
    this.messageBus.subscribe(path, async (msg) => {
      const eventData = await this.discoursePostEventApi.event(msg.id);
      this.event.updateFromEvent(eventData);
    });

    return () => this.messageBus.unsubscribe(path);
  });

  constructor() {
    super(...arguments);
    if (this.isPartialEvent) {
      this.loadEvent();
    }
  }

  get event() {
    return this.fetchedEvent ?? this.args.event;
  }

  get isPartialEvent() {
    return !this.args.event?.creator;
  }

  get loadingDetails() {
    return this.isLoading && this.isPartialEvent;
  }

  getDisplayTime(time) {
    if (this.event.allDay) {
      return moment(time, "YYYY-MM-DD");
    } else if (this.event.showLocalTime) {
      return moment.tz(time, this.event.timezone || "UTC");
    } else {
      return moment
        .utc(time)
        .tz(this.currentUser?.user_option?.timezone || moment.tz.guess());
    }
  }

  get clampDescription() {
    return this.args.clampDescription ?? false;
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
    return this.event.name || this.event.post?.topic?.title;
  }

  get isPublicEvent() {
    return this.event.status === "public";
  }

  get showStatus() {
    if (this.currentUser) {
      return this.event.canUpdateAttendance;
    }
    // Anonymous users can RSVP on public events unless the site is
    // invite-only without requiring login (in which case they can't
    // complete the signup flow anyway).
    if (this.siteSettings.invite_only && !this.siteSettings.login_required) {
      return false;
    }
    return this.event.isPublic && !this.event.isClosed && !this.event.isExpired;
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

  get recurrenceLabel() {
    if (!this.event?.recurrence) {
      return null;
    }

    return i18n(
      `discourse_post_event.builder_modal.recurrence.${this.event.recurrence}`,
      recurrenceContext(recurrenceRef(this.event))
    );
  }

  async loadEvent() {
    if (this.fetchedEvent || !this.args.event) {
      return;
    }

    this.isLoading = true;

    try {
      const fetched = await this.discoursePostEventApi.event(
        this.args.event.id
      );
      const displayedStartsAt = this.args.event.startsAt;

      if (
        fetched.recurrence &&
        displayedStartsAt &&
        fetched.startsAt &&
        displayedStartsAt !== fetched.startsAt
      ) {
        this.#filterForFutureOccurrence(fetched);
      }

      fetched.startsAt = displayedStartsAt;
      fetched.endsAt = this.args.event.endsAt;
      this.fetchedEvent = fetched;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }

  #filterForFutureOccurrence(event) {
    event.sampleInvitees = event.sampleInvitees.filter(
      (invitee) => invitee.status !== "going" || invitee.recurring
    );

    const recurringCount = event.stats?.goingRecurring ?? 0;
    if (event.stats) {
      event.stats.going = recurringCount;
    }
    event.atCapacity =
      event.maxAttendees != null && recurringCount >= event.maxAttendees;

    if (
      event.watchingInvitee?.status === "going" &&
      !event.watchingInvitee?.recurring
    ) {
      event.watchingInvitee = null;
    }
  }

  <template>
    {{#let this.event as |event|}}
      <div class="discourse-post-event">
        <div class="discourse-post-event-widget">
          {{#if event}}
            <Image
              @imageUpload={{event.imageUpload}}
              @alt={{this.eventName}}
              @linkToPost={{@linkToPost}}
              @postUrl={{event.post.url}}
              @post={{@post}}
            />
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
                      href={{getURL event.post.url}}
                      rel="noopener noreferrer"
                    >{{dReplaceEmoji this.eventName}}</a>
                  {{else}}
                    {{dReplaceEmoji this.eventName}}
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
                    {{#if event.creator}}
                      <EventStatus @event={{event}} />
                      <StatusSeparator />
                      <Creator @user={{event.creator}} />
                    {{else if this.loadingDetails}}
                      <CreatorPlaceholder />
                    {{/if}}
                  </PluginOutlet>
                </div>
              </div>

              <div class="event-header__controls">
                {{#if event.creator}}
                  <MoreMenu
                    @event={{event}}
                    @isStandaloneEvent={{this.isStandaloneEvent}}
                    @composePrivateMessage={{routeAction
                      "composePrivateMessage"
                    }}
                  />
                {{/if}}

                {{#if @onClose}}
                  <DButton
                    class="btn-default btn-small discourse-post-event-close"
                    @icon="xmark"
                    @action={{@onClose}}
                  />
                {{/if}}
              </div>
            </header>

            <PluginOutlet
              @name="discourse-post-event-info"
              @outletArgs={{lazyHash
                event=event
                Section=(component InfoSection event=event)
                Url=(component Url url=event.url)
                Description=(component
                  Description
                  description=event.description
                  clamp=this.clampDescription
                )
                Location=(component
                  DiscoursePostEventLocation event=event location=event.location
                )
                Dates=(component
                  Dates event=event expiredAndRecurring=this.expiredAndRecurring
                )
                Recurrence=(component
                  InfoSection icon="arrows-rotate" class="event-recurrence"
                )
                recurrenceLabel=this.recurrenceLabel
                Invitees=(component Invitees event=event)
                Status=(component Status event=event)
                ChatChannel=(component ChatChannel event=event)
                Image=(component
                  Image
                  imageUpload=event.imageUpload
                  alt=this.eventName
                  linkToPost=@linkToPost
                  postUrl=event.post.url
                  post=@post
                )
              }}
            >
              <Dates
                @event={{event}}
                @expiredAndRecurring={{this.expiredAndRecurring}}
              />
              {{#if event.recurrence}}
                <InfoSection @icon="arrows-rotate" class="event-recurrence">
                  {{this.recurrenceLabel}}
                </InfoSection>
              {{/if}}
              <DiscoursePostEventLocation @event={{event}} />
              <Url @url={{event.url}} />
              <ChatChannel @event={{event}} />

              {{#if event.stats}}
                <Invitees @event={{event}} />
              {{else if this.loadingDetails}}
                <InviteesPlaceholder />
              {{/if}}

              {{#if this.withDescription}}
                <Description
                  @descriptionHtml={{event.descriptionHtml}}
                  @clamp={{this.clampDescription}}
                />
              {{/if}}

              {{#if this.showStatus}}
                <Status @event={{event}} />
              {{else if this.loadingDetails}}
                <StatusPlaceholder />
              {{/if}}

              {{#unless @hideLivestreamVideo}}
                {{#if event.livestream}}
                  {{bodyClass "livestream-topic"}}
                {{/if}}
                <Livestream @event={{event}} />
              {{/unless}}
            </PluginOutlet>
          {{/if}}
        </div>
      </div>
    {{/let}}
  </template>
}
