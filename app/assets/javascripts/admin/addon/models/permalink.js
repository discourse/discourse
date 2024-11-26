import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import RestModel from "discourse/models/rest";
import discourseComputed from "discourse-common/utils/decorators";

export default class Permalink extends RestModel {
  static findAll(filter) {
    return ajax("/admin/permalinks.json", { data: { filter } }).then(function (
      permalinks
    ) {
      return permalinks.map((p) => Permalink.create(p));
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

  @discourseComputed("url")
  key(url) {
    return url.replace("/", "_");
  }
}
