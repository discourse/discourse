import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

// handles legacy /tag/:tag_name URLs
// by redirecting to the canonical /tag/:slug/:id format
export default class TagLegacyRedirect extends DiscourseRoute {
  @service router;

  async beforeModel() {
    const tagName = this.paramsFor("tag.legacyRedirect").tag_name;
    const result = await ajax(`/tag/${tagName}/info.json`);
    const tag = result.tag_info;
    this.router.replaceWith("tag.show", tag.slug, tag.id);
  }
}
