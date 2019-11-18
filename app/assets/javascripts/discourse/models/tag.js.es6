import discourseComputed from "discourse-common/utils/decorators";
import RestModel from "discourse/models/rest";

export default RestModel.extend({
  @discourseComputed("count", "pm_count")
  totalCount(count, pmCount) {
    return count + pmCount;
  },

  @discourseComputed("count", "pm_count")
  pmOnly(count, pmCount) {
    return count === 0 && pmCount > 0;
  },

  @discourseComputed("id")
  searchContext(id) {
    return { type: "tag", id, tag: this, name: id };
  }
});
