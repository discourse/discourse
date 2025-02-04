import DiscourseRoute from "discourse/routes/discourse";
import Permalink from "admin/models/permalink";

export default class AdminPermalinksRoute extends DiscourseRoute {
  model() {
    return Permalink.findAll();
  }
}
