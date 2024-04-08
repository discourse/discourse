import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "discourse-i18n";

export default DiscourseRoute.extend({
  model() {
    return ajax("/about.json").then((result) => {
      const yearAgo = moment().locale("en").utc().subtract(1, "year");
      result.about.admins = result.about.admins.filter(
        (r) => moment(r.last_seen_at) > yearAgo
      );
      result.about.moderators = result.about.moderators.filter(
        (r) => moment(r.last_seen_at) > yearAgo
      );
      return result.about;
    });
  },

  titleToken() {
    return I18n.t("about.simple_title");
  },
});
