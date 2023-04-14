import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";

export default DiscourseRoute.extend({
  showFooter: true,

  titleToken() {
    return I18n.t("groups.manage.interaction.title");
  },
});
