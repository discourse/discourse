import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default class AdminCustomizeLlmsTxtRoute extends Route {
  model() {
    return ajax("/admin/customize/llms");
  }
}
