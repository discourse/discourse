import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  showFooter: true,

  titleToken() {
    return I18n.t("groups.manage.profile.title");
  }
});
