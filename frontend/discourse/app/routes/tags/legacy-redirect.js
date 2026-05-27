import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

// handles super legacy /tags/:tag_name (note plural) URLs
// by redirecting to the canonical /tag/:slug/:id format
export default class TagsLegacyRedirect extends DiscourseRoute {
  @service router;

  async beforeModel() {
    const tagName = this.paramsFor("tags.legacyRedirect").tag_name;
    const result = await ajax(`/tag/${tagName}/info.json`);
    const tag = result.tag_info;
    this.router.replaceWith("tag.show", tag.slug, tag.id);
  }
}
