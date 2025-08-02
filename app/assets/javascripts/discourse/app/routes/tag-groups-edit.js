import DiscourseRoute from "discourse/routes/discourse";

export default class TagGroupsEdit extends DiscourseRoute {
  model(params) {
    return this.store.find("tagGroup", params.id);
  }

  afterModel(tagGroup) {
    tagGroup.set("savingStatus", null);
  }
}
