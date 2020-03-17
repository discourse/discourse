import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default Route.extend({
  model() {
    return ajax("/admin/customize/robots");
  }
});
