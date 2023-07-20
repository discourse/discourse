import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class AdminCustomizeRobotsTxtRoute extends Route {
  model() {
    return ajax("/admin/customize/robots");
  }
}
