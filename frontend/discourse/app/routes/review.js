import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class Review extends DiscourseRoute {
  titleToken() {
    return i18n("review.title");
  }
}
