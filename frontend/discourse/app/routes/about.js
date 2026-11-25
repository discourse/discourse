import { service } from "@ember/service";
import Category from "discourse/models/category";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class About extends DiscourseRoute {
  @service about;
  @service site;

  async model() {
    const result = await this.about.load({ refresh: true });
    result.categories?.forEach((category) => {
      this.site.updateCategory(category);
    });

    result.about.category_moderators?.forEach((obj) => {
      obj.category = Category.findById(obj.category_id);
    });

    return result.about;
  }

  titleToken() {
    return i18n("about.simple_title");
  }
}
