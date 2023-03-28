import I18n from "I18n";

import DiscourseRoute from "discourse/routes/discourse";
import { isEmpty } from "@ember/utils";
import { action } from "@ember/object";

export default class extends DiscourseRoute {
  queryParams = {
    status: { replace: true, refreshModel: true },
  };

  model(data) {
    return this.store.findFiltered("topicList", {
      filter: "filter",
      params: this.#filterQueryParams(data),
    });
  }

  titleToken() {
    const filterText = I18n.t("filters.filter.title");
    return I18n.t("filters.with_topics", { filter: filterText });
  }

  setupController(_controller, model) {
    this.controllerFor("discovery/topics").setProperties({ model });
  }

  renderTemplate() {
    this.render("navigation/filter", { outlet: "navigation-bar" });

    this.render("discovery/topics", {
      controller: "discovery/topics",
      outlet: "list-container",
    });
  }

  // TODO(tgxworld): This action is required by the `discovery/topics` controller which is not necessary for this route.
  // Figure out a way to remove this.
  @action
  changeSort() {}

  #filterQueryParams(data) {
    const params = {};

    Object.keys(this.queryParams).forEach((key) => {
      if (!isEmpty(data[key])) {
        params[key] = data[key];
      }
    });

    return params;
  }
}
