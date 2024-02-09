import { readOnly } from "@ember/object/computed";
import RestModel from "discourse/models/rest";
import discourseComputed from "discourse-common/utils/decorators";

export default class Tag extends RestModel {
  @readOnly("pm_only") pmOnly;

  @discourseComputed("count", "pm_count")
  totalCount(count, pmCount) {
    return pmCount ? count + pmCount : count;
  }

  @discourseComputed("id")
  searchContext(id) {
    return { type: "tag", id, tag: this, name: id };
  }
}
