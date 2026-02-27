import { readOnly } from "@ember/object/computed";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import RestModel from "discourse/models/rest";

export default class Tag extends RestModel {
  @readOnly("pm_only") pmOnly;

  @discourseComputed("slug", "id")
  url(slug, id) {
    if (id) {
      const slugForUrl = slug || `${id}-tag`;
      return getURL(`/tag/${slugForUrl}/${id}`);
    }
    // fallback for tags without id (legacy)
    return getURL(`/tag/${this.name}`);
  }

  @discourseComputed("count", "pm_count")
  totalCount(count, pmCount) {
    return pmCount ? count + pmCount : count;
  }

  @discourseComputed("id", "name")
  searchContext(id, name) {
    return {
      type: "tag",
      id,
      /** @type Tag */
      tag: this,
      name,
    };
  }
}
