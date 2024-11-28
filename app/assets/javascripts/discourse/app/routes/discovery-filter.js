import { setTopicList } from "discourse/lib/topic-list-tracker";
import { escapeExpression } from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class DiscoveryFilterRoute extends DiscourseRoute {
  queryParams = {
    q: { refreshModel: true },
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
    const query = this.paramsFor(this.routeName).q;
    return i18n("filters.filter.title", { filter: escapeExpression(query) });
  }
}
