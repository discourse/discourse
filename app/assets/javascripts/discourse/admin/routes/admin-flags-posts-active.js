import DiscourseRoute from "discourse/routes/discourse";

export default class AdminFlagsPostsActiveRoute extends DiscourseRoute {
  model() {
    return this.store.findAll("flagged-post", { filter: "active" });
  }
}
