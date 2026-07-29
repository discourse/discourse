import RestCompatModel from "discourse/data/rest-compat";
import { TagSchema } from "discourse/data/schemas/tag";
import { defineFieldForwarders } from "discourse/data/warp-rest-model";
import getURL from "discourse/lib/get-url";

export default class Tag extends RestCompatModel {
  static type = "tag";

  get pmOnly() {
    return this.pm_only;
  }

  get url() {
    if (this.id) {
      const slugForUrl = this.slug || `${this.id}-tag`;
      return getURL(`/tag/${slugForUrl}/${this.id}`);
    }
    // fallback for tags without id (legacy)
    return getURL(`/tag/${this.name.replaceAll(".", "%2E")}`);
  }

  get totalCount() {
    return this.pm_count ? this.count + this.pm_count : this.count;
  }

  get searchContext() {
    return {
      type: "tag",
      id: this.id,
      tag: this,
      name: this.name,
    };
  }
}

defineFieldForwarders(Tag, TagSchema);
