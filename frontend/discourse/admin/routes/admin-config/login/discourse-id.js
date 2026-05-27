import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class AdminConfigLoginDiscourseIdRoute extends Route {
  model() {
    return ajax("/admin/config/login-and-authentication/discourse-id");
  }
}
