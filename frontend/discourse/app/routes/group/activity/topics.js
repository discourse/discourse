import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class GroupActivityTopics extends DiscourseRoute {
  titleToken() {
    return i18n(`groups.topics`);
  }

  model(params = {}) {
    return this.store.findFiltered("topicList", {
      filter: `topics/groups/${this.modelFor("group").get("name")}`,
      params,
    });
  }
}
