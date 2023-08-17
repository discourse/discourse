import I18n from "I18n";

import DiscourseRoute from "discourse/routes/discourse";

export default class DiscoveryFilterRoute extends DiscourseRoute {
  queryParams = {
    q: { replace: true, refreshModel: true },
  };

  model(data) {
    return this.store.findFiltered("topicList", {
      filter: "filter",
      params: { q: data.q },
    });
  }

  titleToken() {
    const filterText = I18n.t("filters.filter.title");
    return I18n.t("filters.with_topics", { filter: filterText });
  }
}
