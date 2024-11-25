import { setTopicList } from "discourse/lib/topic-list-tracker";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class DiscoveryFilterRoute extends DiscourseRoute {
  queryParams = {
    q: { replace: true, refreshModel: true },
  };

  comingFromDifferentRoute = true;

  beforeModel(transition) {
    if (transition.from && transition.from.name !== this.routeName) {
      this.comingFromDifferentRoute = true;
    } else {
      this.comingFromDifferentRoute = false;
    }

    super.beforeModel(...arguments);
  }

  setupController(controller, model) {
    super.setupController(controller, model);

    const qParamConfig = this.queryParams.q;
    qParamConfig.replace = !this.comingFromDifferentRoute;
  }

  async model(data) {
    const list = await this.store.findFiltered("topicList", {
      filter: "filter",
      params: { q: data.q },
    });

    setTopicList(list);

    return list;
  }

  titleToken() {
    const filterText = i18n("filters.filter.title");
    return i18n("filters.with_topics", { filter: filterText });
  }
}
