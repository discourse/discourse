import discourseComputed from "discourse-common/utils/decorators";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";

export default Controller.extend({
  discovery: inject(),
  discoveryTopics: inject("discovery/topics"),

  @discourseComputed("discoveryTopics.model", "discoveryTopics.model.draft")
  draft: function() {
    return this.get("discoveryTopics.model.draft");
  }
});
