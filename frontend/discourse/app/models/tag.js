import { tracked } from "@glimmer/tracking";
import { dependentKeyCompat } from "@ember/object/compat";
import discourseComputed from "discourse/lib/decorators";
import RestModel from "discourse/models/rest";

export default class Tag extends RestModel {
  @tracked pm_only;

  @dependentKeyCompat
  get pmOnly() {
    return this.pm_only;
  }

  @discourseComputed("count", "pm_count")
  totalCount(count, pmCount) {
    return pmCount ? count + pmCount : count;
  }

  @discourseComputed("id")
  searchContext(id) {
    return {
      type: "tag",
      id,
      /** @type Tag */
      tag: this,
      name: id,
    };
  }
}
