import discourseComputed from "discourse-common/utils/decorators";
import Controller, { inject as controller } from "@ember/controller";
import FilterModeMixin from "discourse/mixins/filter-mode";

export default Controller.extend(FilterModeMixin, {
  discovery: controller(),
  discoveryTopics: controller("discovery/topics"),

  @discourseComputed("discoveryTopics.model", "discoveryTopics.model.draft")
  draft: function() {
    return this.get("discoveryTopics.model.draft");
  }
});
