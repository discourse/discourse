import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default DiscourseRoute.extend({
  model() {
    return ajax("/about.json").then((result) => {
      let activeAdmins = [];
      let activeModerators = [];
      const yearAgo = moment().locale("en").utc().subtract(1, "year");
      result.about.admins.forEach((r) => {
        if (moment(r.last_seen_at) > yearAgo) {
          activeAdmins.push(r);
        }
      });
      result.about.moderators.forEach((r) => {
        if (moment(r.last_seen_at) > yearAgo) {
          activeModerators.push(r);
        }
      });
      result.about.admins = activeAdmins;
      result.about.moderators = activeModerators;

      const { category_moderators: categoryModerators } = result.about;
      if (categoryModerators && categoryModerators.length) {
        categoryModerators.forEach((obj, index) => {
          const category = Category.findById(obj.category_id);
          result.about.category_moderators[index].category = category;
        });
      }

      return result.about;
    });
  },

  titleToken() {
    return I18n.t("about.simple_title");
  },
});
