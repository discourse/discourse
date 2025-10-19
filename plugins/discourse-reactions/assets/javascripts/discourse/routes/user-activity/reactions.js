import { TrackedArray } from "@ember-compat/tracked-built-ins";
import DiscourseRoute from "discourse/routes/discourse";
import CustomReaction from "../../models/discourse-reactions-custom-reaction";

export default class UserActivityReactions extends DiscourseRoute {
  model() {
    const list = CustomReaction.findReactions(
      "reactions",
      this.modelFor("user").username
    );

    return new TrackedArray(list);
  }

  setupController(controller, model) {
    let loadedAll = model.length < 20;
    this.controllerFor("user-activity.reactions").setProperties({
      model,
      canLoadMore: !loadedAll,
      reactionsUrl: "reactions",
      username: this.modelFor("user").username,
    });
  }
}
