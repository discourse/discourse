import I18n from "I18n";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  showFooter: true,

  titleToken() {
    return I18n.t("groups.manage.tags.title");
  }
});
