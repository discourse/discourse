import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class TagEditIndexRoute extends Route {
  @service router;

  redirect() {
    const params = this.paramsFor("tag.edit");
    this.router.replaceWith(
      "tag.edit.tab",
      params.tag_slug,
      params.tag_id,
      "general"
    );
  }
}
