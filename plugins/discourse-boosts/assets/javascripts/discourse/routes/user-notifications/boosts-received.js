import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { flattenBoost, PAGE_SIZE } from "../user-activity/boosts";

export default class UserNotificationsBoostsReceived extends DiscourseRoute {
  templateName = "user-activity/boosts";
  controllerName = "user-activity.boosts";

  async model() {
    const username = this.modelFor("user").username;
    const result = await ajax(
      `/discourse-boosts/users/${username}/boosts-received.json`
    );
    const boosts = result.boosts || [];
    return new TrackedArray(boosts.map(flattenBoost));
  }

  setupController(controller, model) {
    const loadedAll = model.length < PAGE_SIZE;
    this.controllerFor("user-activity.boosts").setProperties({
      model,
      canLoadMore: !loadedAll,
      username: this.modelFor("user").username,
      boostsUrl: "boosts-received",
    });
  }
}
