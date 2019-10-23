import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

// should be kept in sync with 'UserSummary::MAX_SUMMARY_RESULTS'
const MAX_SUMMARY_RESULTS = 6;

export default Component.extend({
  tagName: "",

  @computed("items.length")
  hasMore(length) {
    return length >= MAX_SUMMARY_RESULTS;
  }
});
