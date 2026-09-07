import { service } from "@ember/service";
import { setTopicList } from "discourse/lib/topic-list-tracker";
import { escapeExpression } from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class DiscoveryFilterRoute extends DiscourseRoute {
  @service filterTopicTracking;
  @service topicTrackingState;

  queryParams = {
    q: { refreshModel: true },
  };

  async model(data) {
    const list = await this.store.findFiltered("topicList", {
      filter: "filter",
      params: { q: data.q },
    });

    this.topicTrackingState.sync(list, "filter", { q: data.q });
    setTopicList(list);

    return list;
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    this.filterTopicTracking.update(
      this.paramsFor(this.routeName).q,
      model.topic_list.filter_new_topic_ids
    );
  }

  deactivate() {
    super.deactivate(...arguments);
    this.filterTopicTracking.stop();
  }

  titleToken() {
    const query = this.paramsFor(this.routeName).q;
    return i18n("filters.filter.title", { filter: escapeExpression(query) });
  }
}
