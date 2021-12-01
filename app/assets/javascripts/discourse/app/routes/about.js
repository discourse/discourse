import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { action } from "@ember/object";

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
          const category = this.site.categories.findBy("id", obj.category_id);
          result.about.category_moderators[index].category = category;
        });
      }
      return result.about;
    });
  },

  titleToken() {
    return I18n.t("about.simple_title");
  },

  @action
  didTransition() {
    this.controllerFor("application").set("showFooter", true);
    return true;
  },
});
