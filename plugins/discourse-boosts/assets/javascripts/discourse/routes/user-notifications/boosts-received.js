import { trackedArray } from "@ember/reactive/collections";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { flattenBoost, PAGE_SIZE } from "../../lib/boosts-stream";

export default class UserNotificationsBoostsReceived extends DiscourseRoute {
  async model() {
    const username = this.modelFor("user").username;
    const result = await ajax(
      `/discourse-boosts/users/${username}/boosts-received.json`
    );
    const boosts = result.boosts || [];
    return {
      boosts: trackedArray(boosts.map(flattenBoost)),
      canLoadMore: boosts.length >= PAGE_SIZE,
      username,
      boostsUrl: "boosts-received",
    };
  }
}
