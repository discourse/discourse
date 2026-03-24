import { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import RestModel from "discourse/models/rest";

export default class Permalink extends RestModel {
  static async findAll(filter) {
    const data = await ajax("/admin/permalinks.json", { data: { filter } });
    return data.map((p) => Permalink.create(p));
  }

  @computed("category_id")
  get category() {
    return Category.findById(this.category_id);
  }

  @computed("external_url")
  get linkIsExternal() {
    return !DiscourseURL.isInternal(this.external_url);
  }

  @computed("url")
  get key() {
    return this.url.replace("/", "_");
  }
}
