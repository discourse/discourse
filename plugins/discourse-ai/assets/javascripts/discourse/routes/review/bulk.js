import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class ReviewBulk extends DiscourseRoute {
  model() {
    return ajax("/review/bulk.json");
  }
}
