import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class BlogThemesEditRoute extends DiscourseRoute {
  model({ id }) {
    return ajax(`/blog/themes/${encodeURIComponent(id)}.json`);
  }
}
