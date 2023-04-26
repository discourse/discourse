import RestModel from "discourse/models/rest";
import discourseComputed from "discourse-common/utils/decorators";
import { readOnly } from "@ember/object/computed";

export default RestModel.extend({
  pmOnly: readOnly("pm_only"),

  @discourseComputed("count", "pm_count")
  totalCount(count, pmCount) {
    return pmCount ? count + pmCount : count;
  },

  @discourseComputed("id")
  searchContext(id) {
    return { type: "tag", id, tag: this, name: id };
  },
});
