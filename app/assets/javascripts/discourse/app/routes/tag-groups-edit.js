import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model(params) {
    return this.store.find("tagGroup", params.id);
  },

  afterModel(tagGroup) {
    tagGroup.set("savingStatus", null);
  },
});
