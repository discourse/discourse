import { TrackedArray } from "@ember-compat/tracked-built-ins";
import DiscourseRoute from "discourse/routes/discourse";
import CustomReaction, {
  PAGE_SIZE,
} from "../../models/discourse-reactions-custom-reaction";

export default class UserActivityReactions extends DiscourseRoute {
  async model() {
    const list = await CustomReaction.findReactions(
      "reactions",
      this.modelFor("user").username
    );

    return new TrackedArray(
      list.map((reaction) => CustomReaction.flattenForPostList(reaction))
    );
  }

  setupController(controller, model) {
    let loadedAll = model.length < PAGE_SIZE;
    this.controllerFor("user-activity.reactions").setProperties({
      model,
      canLoadMore: !loadedAll,
      reactionsUrl: "reactions",
      username: this.modelFor("user").username,
    });
  }
}
