import DiscourseController  from "discourse/controllers/controller";
import { translateResults } from "discourse/lib/search-for-term";

export default DiscourseController.extend({
  needs: ["application"],

  loading: Em.computed.not("model"),
  queryParams: ["q"],
  q: null,

  modelChanged: function() {
    if (this.get("searchTerm") !== this.get("q")) {
      this.set("searchTerm", this.get("q"));
    }
  }.observes("model"),

  qChanged: function() {
    const model = this.get("model");
    if (model && this.get("model.q") !== this.get("q")) {
      this.set("searchTerm", this.get("q"));
      this.send("search");
    }
  }.observes("q"),

  _showFooter: function() {
    this.set("controllers.application.showFooter", !this.get("loading"));
  }.observes("loading"),

  actions: {
    search() {
      this.set("q", this.get("searchTerm"));
      this.set("model", null);

      Discourse.ajax("/search", { data: { q: this.get("searchTerm") } }).then(results => {
        this.set("model", translateResults(results) || {});
        this.set("model.q", this.get("q"));
      });
    }
  }
});
