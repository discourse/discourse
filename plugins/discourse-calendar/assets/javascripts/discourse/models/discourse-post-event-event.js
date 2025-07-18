import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { bind } from "discourse/lib/decorators";
import { optionalRequire } from "discourse/lib/utilities";
import User from "discourse/models/user";
import DiscoursePostEventEventStats from "./discourse-post-event-event-stats";
import DiscoursePostEventInvitee from "./discourse-post-event-invitee";

const ChatChannel = optionalRequire(
  "discourse/plugins/chat/discourse/models/chat-channel"
);

const DEFAULT_REMINDER = {
  type: "notification",
  value: 15,
  unit: "minutes",
  period: "before",
};

export default class DiscoursePostEventEvent {
  static create(args = {}) {
    return new DiscoursePostEventEvent(args);
  }

  @tracked title;
  @tracked name;
  @tracked categoryId;
  @tracked startsAt;
  @tracked endsAt;
  @tracked rawInvitees;
  @tracked location;
  @tracked url;
  @tracked description;
  @tracked timezone;
  @tracked showLocalTime;
  @tracked status;
  @tracked post;
  @tracked minimal;
  @tracked chatEnabled;
  @tracked canUpdateAttendance;
  @tracked canActOnDiscoursePostEvent;
  @tracked shouldDisplayInvitees;
  @tracked isClosed;
  @tracked isExpired;
  @tracked isStandalone;
  @tracked recurrenceUntil;
  @tracked recurrence;
  @tracked recurrenceRule;
  @tracked customFields;
  @tracked channel;

  @tracked _watchingInvitee;
  @tracked _sampleInvitees;
  @tracked _stats;
  @tracked _creator;
  @tracked _reminders;

  constructor(args = {}) {
    this.id = args.id;
    this.name = args.name;
    this.categoryId = args.category_id;
    this.upcomingDates = args.upcoming_dates;
    this.startsAt = args.starts_at;
    this.endsAt = args.ends_at;
    this.rawInvitees = args.raw_invitees;
    this.sampleInvitees = args.sample_invitees || [];
    this.location = args.location;
    this.url = args.url;
    this.description = args.description;
    this.timezone = args.timezone;
    this.showLocalTime = args.show_local_time;
    this.status = args.status;
    this.creator = args.creator;
    this.post = args.post;
    this.isClosed = args.is_closed;
    this.isExpired = args.is_expired;
    this.isStandalone = args.is_standalone;
    this.minimal = args.minimal;
    this.chatEnabled = args.chat_enabled;
    this.recurrenceRule = args.recurrence_rule;
    this.recurrence = args.recurrence;
    this.recurrenceUntil = args.recurrence_until;
    this.canUpdateAttendance = args.can_update_attendance;
    this.canActOnDiscoursePostEvent = args.can_act_on_discourse_post_event;
    this.shouldDisplayInvitees = args.should_display_invitees;
    this.watchingInvitee = args.watching_invitee;
    this.stats = args.stats;
    this.reminders = args.reminders;
    this.customFields = EmberObject.create(args.custom_fields || {});
    if (args.channel && ChatChannel) {
      this.channel = ChatChannel.create(args.channel);
    }
  }

  get watchingInvitee() {
    return this._watchingInvitee;
  }

  set watchingInvitee(invitee) {
    this._watchingInvitee = invitee
      ? DiscoursePostEventInvitee.create(invitee)
      : null;
  }

  get sampleInvitees() {
    return this._sampleInvitees;
  }

  set sampleInvitees(invitees = []) {
    this._sampleInvitees = new TrackedArray(
      invitees.map((i) => DiscoursePostEventInvitee.create(i))
    );
  }

  get stats() {
    return this._stats;
  }

  set stats(stats) {
    this._stats = this.#initStatsModel(stats);
  }

  get reminders() {
    return this._reminders;
  }

  set reminders(reminders = []) {
    this._reminders = new TrackedArray(reminders);
  }

  get creator() {
    return this._creator;
  }

  set creator(user) {
    this._creator = this.#initUserModel(user);
  }

  get isPublic() {
    return this.status === "public";
  }

  get isPrivate() {
    return this.status === "private";
  }

  updateFromEvent(event) {
    this.name = event.name;
    this.startsAt = event.startsAt;
    this.endsAt = event.endsAt;
    this.location = event.location;
    this.url = event.url;
    this.timezone = event.timezone;
    this.showLocalTime = event.showLocalTime;
    this.description = event.description;
    this.status = event.status;
    this.creator = event.creator;
    this.isClosed = event.isClosed;
    this.isExpired = event.isExpired;
    this.isStandalone = event.isStandalone;
    this.minimal = event.minimal;
    this.chatEnabled = event.chatEnabled;
    this.recurrenceRule = event.recurrenceRule;
    this.recurrence = event.recurrence;
    this.recurrenceUntil = event.recurrenceUntil;
    this.canUpdateAttendance = event.canUpdateAttendance;
    this.canActOnDiscoursePostEvent = event.canActOnDiscoursePostEvent;
    this.shouldDisplayInvitees = event.shouldDisplayInvitees;
    this.stats = event.stats;
    this.sampleInvitees = event.sampleInvitees || [];
    this.reminders = event.reminders;
  }

  @bind
  removeReminder(reminder) {
    const index = this.reminders.findIndex((r) => r.id === reminder.id);
    if (index > -1) {
      this.reminders.splice(index, 1);
    }
  }

  @bind
  addReminder(reminder) {
    reminder ??= { ...DEFAULT_REMINDER };
    this.reminders.push(reminder);
  }

  #initUserModel(user) {
    if (!user || user instanceof User) {
      return user;
    }

    return User.create(user);
  }

  #initStatsModel(stats) {
    if (!stats || stats instanceof DiscoursePostEventEventStats) {
      return stats;
    }

    return DiscoursePostEventEventStats.create(stats);
  }
}
