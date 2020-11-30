import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

export default DiscourseRoute.extend({
  showFooter: true,

  beforeModel() {
    if (!this.siteSettings.tagging_enabled) {
      this.transitionTo("tagGroups");
    }
  },

  model() {
    return this.store.createRecord("tagGroup", {
      name: I18n.t("tagging.groups.new_name"),
    });
  },
});
