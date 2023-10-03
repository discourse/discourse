import I18n from "I18n";

import DiscourseRoute from "discourse/routes/discourse";
import { action } from "@ember/object";

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

  setupController(_controller, model) {
    this.controllerFor("discovery/topics").setProperties({ model });

    this.controllerFor("navigation/filter").setProperties({
      newQueryString: this.paramsFor("discovery.filter").q,
    });
  }

  renderTemplate() {
    this.render("navigation/filter", { outlet: "navigation-bar" });

    this.render("discovery/topics", {
      controller: "discovery/topics",
      outlet: "list-container",
    });
  }

  // TODO(tgxworld): The following 2 actions are required by the `discovery/topics` controller which is not necessary for this route.
  // Figure out a way to remove this.
  @action
  changeSort() {}

  @action
  changeNewListSubset() {}
}
