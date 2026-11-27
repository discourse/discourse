import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class HamiltonRoadmapRoute extends DiscourseRoute {
  model() {
    return ajax("/hamilton/docs/roadmap.json");
  }

  titleToken() {
    return i18n("hamilton.roadmap");
  }
}
