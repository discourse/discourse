import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { homepageNavigationDestination } from "discourse/lib/homepage-router-overrides";
import DiscourseRoute from "discourse/routes/discourse";
import urlFlagSet from "discourse/plugins/live/discourse/lib/live/url-flag";

export default class LiveRoomRoute extends DiscourseRoute {
  @service currentUser;
  @service liveRooms;
  @service liveWebrtc;
  @service router;

  async model(params) {
    await this.liveRooms.ready;

    const room = this.liveRooms.roomBySlug(params.slug);
    if (room) {
      return room;
    }

    const response = await ajax(`/live/rooms/${params.slug}.json`);
    return response.room;
  }

  afterModel(room, transition) {
    if (!this.#widgetJoinRequested(transition)) {
      return;
    }

    this.liveWebrtc.setCallWidgetHidden(false);
    this.liveWebrtc.join(room);

    // The widget only renders off the room page, so the room page is never
    // entered: navigating within the app stays put, and a full page load lands
    // on the homepage with the call already floating.
    if (transition.from) {
      transition.abort();
      return;
    }

    this.router.replaceWith(homepageNavigationDestination());
  }

  titleToken() {
    return this.currentModel?.name;
  }

  // `widget` says where a call should live, not that there should be one, so it
  // composes with `join` instead of implying it. Skipping the room page is only
  // right when both are asked for: `?widget` on its own opens the room page,
  // which then docks whatever the user joins from there.
  #widgetJoinRequested(transition) {
    // Anonymous visitors cannot join a call, so they get the room page and its
    // login prompt instead.
    if (!this.currentUser) {
      return false;
    }

    const { join, widget } = transition.to?.queryParams ?? {};

    return urlFlagSet(widget) && urlFlagSet(join);
  }
}
