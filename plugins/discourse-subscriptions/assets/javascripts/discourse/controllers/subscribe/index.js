import Controller from "@ember/controller";
import { computed } from "@ember/object";
import User from "discourse/models/user";

export default class SubscribeIndexController extends Controller {
  @computed()
  get isLoggedIn() {
    return User.current();
  }
}
