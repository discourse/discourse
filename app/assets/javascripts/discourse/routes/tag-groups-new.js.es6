import DiscourseRoute from "discourse/routes/discourse";
import TagGroup from "discourse/models/tag-group";

export default DiscourseRoute.extend({
  showFooter: true,

  beforeModel() {
    let newTagGroup = TagGroup.create({
      id: "new",
      name: I18n.t("tagging.groups.new_name")
    });

    this.controllerFor('tag-groups').send("selectTagGroup", newTagGroup);
  }
});
