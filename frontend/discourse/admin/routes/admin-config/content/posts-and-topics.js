import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminConfigContentPostsAndTopicsRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.content.sub_pages.posts_and_topics.title");
  }
}
