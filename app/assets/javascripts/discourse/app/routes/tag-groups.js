import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

export default DiscourseRoute.extend({
  showFooter: true,

  model() {
    return this.store.findAll("tagGroup");
  },

  titleToken() {
    return I18n.t("tagging.groups.title");
  },
});
