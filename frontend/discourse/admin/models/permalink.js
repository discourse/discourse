import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import RestModel from "discourse/models/rest";

export default class Permalink extends RestModel {
  static async findAll(filter) {
    const data = await ajax("/admin/permalinks.json", { data: { filter } });
    return data.map((p) => Permalink.create(p));
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
