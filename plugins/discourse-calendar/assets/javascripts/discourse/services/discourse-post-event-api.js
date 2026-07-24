import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscoursePostEventEvent from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-event";
import DiscoursePostEventInvitee from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-invitee";
import DiscoursePostEventInvitees from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-invitees";

/**
 * Discourse post event API service. Provides methods to interact with the discourse post event API.
 *
 * @module DiscoursePostEventApi
 * @implements {@ember/service}
 */
export default class DiscoursePostEventApi extends Service {
  eventsPromise = null;

  #eventsByTopicId = new Map();

  // cached per topic id so the live composer preview (which re-cooks on every
  // keystroke) only hits the endpoint once per linked topic; failed requests
  // are evicted so a transient error doesn't hide the card until a full reload
  cachedEventByTopicId(topicId) {
    if (!this.#eventsByTopicId.has(topicId)) {
      this.#eventsByTopicId.set(
        topicId,
        this.eventByTopicId(topicId).catch(() => {
          this.#eventsByTopicId.delete(topicId);
          return null;
        })
      );
    }
    return this.#eventsByTopicId.get(topicId);
  }

  async event(id, data = {}) {
    const result = await this.#getRequest(`/events/${id}`, data);
    return DiscoursePostEventEvent.create(result.event);
  }

  async eventByTopicId(topicId) {
    const result = await this.#getRequest("/events", {
      topic_id: topicId,
      include_details: true,
      include_closed: true,
      limit: 1,
    });
    const eventData = (result.events || [])[0];
    return eventData ? DiscoursePostEventEvent.create(eventData) : null;
  }

  async events(data = {}) {
    if (this.eventsPromise) {
      this.eventsPromise.abort();
    }
    this.eventsPromise = this.#getRequest("/events", data);
    const response = await this.eventsPromise;
    this.eventsPromise = null;

    return (response.events || []).flatMap((eventData) => {
      const occurrences = eventData.occurrences || [];

      return occurrences.map((occurrence) => {
        return DiscoursePostEventEvent.create({
          ...eventData,
          starts_at: occurrence.starts_at,
          ends_at: occurrence.ends_at,
        });
      });
    });
  }

  async listEventInvitees(event, data = {}) {
    const result = await this.#getRequest(`/events/${event.id}/invitees`, data);
    return DiscoursePostEventInvitees.create(result);
  }

  async updateEvent(event, data = {}) {
    const updatedEvent = await this.#putRequest(`/events/${event.id}`, {
      event: data,
    });
    event.updateFromEvent(updatedEvent);
    return event;
  }

  async updateEventAttendance(event, data = {}) {
    if (!event.watchingInvitee) {
      return;
    }

    const result = await this.#putRequest(
      `/events/${event.id}/invitees/${event.watchingInvitee.id}`,
      { invitee: data }
    );

    event.watchingInvitee = DiscoursePostEventInvitee.create(result.invitee);

    event.sampleInvitees.forEach((invitee) => {
      if (invitee.id === event.watchingInvitee.id) {
        invitee.status = event.watchingInvitee.status;
        invitee.recurring = event.watchingInvitee.recurring;
      }
    });

    event.stats = result.invitee.meta.event_stats;
    event.shouldDisplayInvitees =
      result.invitee.meta.event_should_display_invitees;

    const capacity = Number(event.maxAttendees);
    if (!Number.isNaN(capacity) && capacity > 0) {
      event.atCapacity = Number(event.stats.going) >= capacity;
    }

    return event;
  }

  async leaveEvent(event, invitee) {
    await this.#deleteRequest(`/events/${event.id}/invitees/${invitee.id}`);

    event.sampleInvitees = event.sampleInvitees.filter(
      (i) => i.id !== invitee.id
    );

    if (event.watchingInvitee?.id === invitee.id) {
      event.watchingInvitee = null;
    }

    if (invitee?.status === "going" && Number(event.stats?.going) > 0) {
      event.stats.going = Number(event.stats.going) - 1;
    }

    const capacity = Number(event.maxAttendees);
    if (!Number.isNaN(capacity) && capacity > 0) {
      event.atCapacity = Number(event.stats?.going) >= capacity;
    }
  }

  async joinEvent(event, data = {}) {
    const result = await this.#postRequest(`/events/${event.id}/invitees`, {
      invitee: data,
    });

    const invitee = DiscoursePostEventInvitee.create(result.invitee);

    if (!data.user_id) {
      event.watchingInvitee = invitee;
      event.sampleInvitees.push(event.watchingInvitee);
    }

    if (invitee?.status === "going") {
      event.stats.going = Number(event.stats.going || 0) + 1;
    }

    event.stats = result.invitee.meta.event_stats;
    event.shouldDisplayInvitees =
      result.invitee.meta.event_should_display_invitees;

    const capacity = Number(event.maxAttendees);
    if (!Number.isNaN(capacity) && capacity > 0) {
      event.atCapacity = Number(event.stats.going) >= capacity;
    }

    return invitee;
  }

  get #basePath() {
    return "/discourse-post-event";
  }

  #getRequest(endpoint, data = {}) {
    return ajax(`${this.#basePath}${endpoint}`, {
      type: "GET",
      data,
    });
  }

  #putRequest(endpoint, data = {}) {
    return ajax(`${this.#basePath}${endpoint}`, {
      type: "PUT",
      data,
    });
  }

  #postRequest(endpoint, data = {}) {
    return ajax(`${this.#basePath}${endpoint}`, {
      type: "POST",
      data,
    });
  }

  #deleteRequest(endpoint, data = {}) {
    return ajax(`${this.#basePath}${endpoint}`, {
      type: "DELETE",
      data,
    });
  }
}
