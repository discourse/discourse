import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

export default DiscourseRoute.extend({
  titleToken() {
    return I18n.t(`groups.topics`);
  },

  model() {
    return this.store.findFiltered("topicList", {
      filter: `topics/groups/${this.modelFor("group").get("name")}`,
    });
  },
});
