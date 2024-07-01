import { setTopicList } from "discourse/lib/topic-list-tracker";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default class DiscoveryFilterRoute extends DiscourseRoute {
  queryParams = {
    q: { replace: true, refreshModel: true },
  };

  async model(data) {
    const list = await this.store.findFiltered("topicList", {
      filter: "filter",
      params: { q: data.q },
    });

    setTopicList(list);

    return list;
  }

  titleToken() {
    const filterText = I18n.t("filters.filter.title");
    return I18n.t("filters.with_topics", { filter: filterText });
  }
}
