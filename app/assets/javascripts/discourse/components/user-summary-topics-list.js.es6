import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

// should be kept in sync with 'UserSummary::MAX_SUMMARY_RESULTS'
const MAX_SUMMARY_RESULTS = 6;

export default Component.extend({
  tagName: "",

  @discourseComputed("items.length")
  hasMore(length) {
    return length >= MAX_SUMMARY_RESULTS;
  }
});
