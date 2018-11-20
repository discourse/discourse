import { ajax } from "discourse/lib/ajax";

export default Discourse.Route.extend({
  model() {
    return ajax("/404-body", { dataType: "html" });
  }
});
