import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import RestModel from "discourse/models/rest";
import discourseComputed from "discourse-common/utils/decorators";

export default class Permalink extends RestModel {
  static findAll(filter) {
    return ajax("/admin/permalinks.json").then(function (permalinks) {
      let allLinks = permalinks.map((p) => Permalink.create(p));

      if (!filter) {
        return { allLinks, filteredLinks: allLinks };
      }

      let filteredLinks = permalinks
        .filter((p) => {
          return p.url.includes(filter);
        })
        .map((p) => Permalink.create(p));
      return { allLinks, filteredLinks };
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
