import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default DiscourseRoute.extend({
  titleToken() {
    return I18n.t(`groups.topics`);
  },

  model(params = {}) {
    return this.store.findFiltered("topicList", {
      filter: `topics/groups/${this.modelFor("group").get("name")}`,
      params,
    });
  },
});
