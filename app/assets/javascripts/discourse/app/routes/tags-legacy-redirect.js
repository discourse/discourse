import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class TagsLegacyRedirect extends Route {
  @service router;

  beforeModel() {
    this.router.transitionTo(
      "tag.show",
      this.paramsFor("tags.legacyRedirect").tag_id
    );
  }
}
