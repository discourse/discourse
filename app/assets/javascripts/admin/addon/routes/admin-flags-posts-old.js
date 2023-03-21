import DiscourseRoute from "discourse/routes/discourse";

export default class AdminFlagsPostsOldRoute extends DiscourseRoute {
  model() {
    return this.store.findAll("flagged-post", { filter: "old" });
  }
}
