import StaticPage from "discourse/models/static-page";
import DiscourseRoute from "discourse/routes/discourse";

export default class LoginRequiredRoute extends DiscourseRoute {
  model() {
    return StaticPage.find("login");
  }
}
