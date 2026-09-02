import { computed } from "@ember/object";
import { tagUrl } from "discourse/lib/tag-identity";
import RestModel from "discourse/models/rest";

export default class Tag extends RestModel {
  @computed("pm_only")
  get pmOnly() {
    return this.pm_only;
  }

  @computed("slug", "id", "name")
  get url() {
    return tagUrl(this);
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
