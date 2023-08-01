import Category from "discourse/models/category";
import DiscourseURL from "discourse/lib/url";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";

export default class Permalink extends EmberObject {
  static findAll(filter) {
    return ajax("/admin/permalinks.json", { data: { filter } }).then(function (
      permalinks
    ) {
      return permalinks.map((p) => Permalink.create(p));
    });
  }

  save() {
    return ajax("/admin/permalinks.json", {
      type: "POST",
      data: {
        url: this.url,
        permalink_type: this.permalink_type,
        permalink_type_value: this.permalink_type_value,
      },
    });
  }

  @discourseComputed("category_id")
  category(category_id) {
    return Category.findById(category_id);
  }

  @discourseComputed("external_url")
  linkIsExternal(external_url) {
    return !DiscourseURL.isInternal(external_url);
  }

  destroy() {
    return ajax("/admin/permalinks/" + this.id + ".json", {
      type: "DELETE",
    });
  }
}
