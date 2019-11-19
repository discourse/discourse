import { ajax } from "discourse/lib/ajax";
import EmberObject from "@ember/object";

const Permalink = EmberObject.extend({
  save: function() {
    return ajax("/admin/permalinks.json", {
      type: "POST",
      data: {
        url: this.url,
        permalink_type: this.permalink_type,
        permalink_type_value: this.permalink_type_value
      }
    });
  },

  destroy: function() {
    return ajax("/admin/permalinks/" + this.id + ".json", {
      type: "DELETE"
    });
  }
});

Permalink.reopenClass({
  findAll: function(filter) {
    return ajax("/admin/permalinks.json", { data: { filter: filter } }).then(
      function(permalinks) {
        return permalinks.map(p => Permalink.create(p));
      }
    );
  }
});

export default Permalink;
