import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
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

  @discourseComputed("category_id")
  category: function(category_id) {
    return Category.findById(category_id);
  },

  @discourseComputed("external_url")
  linkIsExternal: function(external_url) {
    return !DiscourseURL.isInternal(external_url);
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
