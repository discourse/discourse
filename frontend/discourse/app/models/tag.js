import { computed } from "@ember/object";
import getURL from "discourse/lib/get-url";
import RestModel from "discourse/models/rest";

export default class Tag extends RestModel {
  @computed("pm_only")
  get pmOnly() {
    return this.pm_only;
  }

  @computed("slug", "id")
  get url() {
    if (this.id) {
      const slugForUrl = this.slug || `${this.id}-tag`;
      return getURL(`/tag/${slugForUrl}/${this.id}`);
    }
    // fallback for tags without id (legacy)
    return getURL(`/tag/${this.name}`);
  }

  @computed("count", "pm_count")
  get totalCount() {
    return this.pm_count ? this.count + this.pm_count : this.count;
  }

  @computed("id", "name")
  get searchContext() {
    return {
      type: "tag",
      id: this.id,
      /** @type Tag */
      tag: this,
      name: this.name,
    };
  }
}
