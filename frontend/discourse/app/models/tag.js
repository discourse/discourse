import { computed } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import RestModel from "discourse/models/rest";

export default class Tag extends RestModel {
  @readOnly("pm_only") pmOnly;

  @computed("count", "pm_count")
  get totalCount() {
    return this.pm_count ? this.count + this.pm_count : this.count;
  }

  @computed("id")
  get searchContext() {
    return {
      type: "tag",
      id: this.id,
      /** @type Tag */
      tag: this,
      name: this.id,
    };
  }
}
