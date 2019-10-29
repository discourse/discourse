import { inject } from '@ember/controller';
import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend({
  discovery: inject(),
  discoveryTopics: inject("discovery/topics"),

  @computed("discoveryTopics.model", "discoveryTopics.model.draft")
  draft: function() {
    return this.get("discoveryTopics.model.draft");
  }
});
