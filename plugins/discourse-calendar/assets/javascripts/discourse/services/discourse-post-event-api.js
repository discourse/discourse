import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscoursePostEventEvent from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-event";
import DiscoursePostEventInvitee from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-invitee";
import DiscoursePostEventInvitees from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-invitees";

/**
 * Discoure post event API service. Provides methods to interact with the discourse post event API.
 *
 * @module DiscoursePostEventApi
 * @implements {@ember/service}
 */
export default class DiscoursePostEventApi extends Service {
  eventsPromise = null;

  async event(id) {
    const result = await this.#getRequest(`/events/${id}`);
    return DiscoursePostEventEvent.create(result.event);
  }

  async events(data = {}) {
    if (this.eventsPromise) {
      this.eventsPromise.abort();
    }
    this.eventsPromise = this.#getRequest("/events", data);
    const result = await this.eventsPromise;
    this.eventsPromise = null;
    return result.events.map((e) => DiscoursePostEventEvent.create(e));
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
