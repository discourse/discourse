import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class BlogThemesIndexRoute extends DiscourseRoute {
  model() {
    return ajax("/blog/themes.json");
  }
}
