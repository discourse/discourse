import Controller from "@ember/controller";
import discourseComputed from "discourse/lib/decorators";
import User from "discourse/models/user";

export default class SubscribeIndexController extends Controller {
  @discourseComputed()
  isLoggedIn() {
    return User.current();
  }
}
