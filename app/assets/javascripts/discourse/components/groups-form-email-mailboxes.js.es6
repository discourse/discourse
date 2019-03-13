import { ajax } from "discourse/lib/ajax";

export default Ember.Component.extend({
  refreshing: null,

  actions: {
    refresh() {
      this.set("refreshing", true);
      return ajax(`/groups/${this.get("model.name")}/mailboxes.json`, {
        type: "GET",
        data: { refresh: true }
      }).then(results => {
        this.set("model.extras.mailboxes", results);
        this.set("refreshing", false);
      });
    }
  }
});
