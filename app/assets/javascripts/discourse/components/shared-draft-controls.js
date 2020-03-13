import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  tagName: "",
  publishing: false,

  @discourseComputed("topic.destination_category_id")
  validCategory(destCatId) {
    return destCatId && destCatId !== this.site.shared_drafts_category_id;
  },

  actions: {
    updateDestinationCategory(categoryId) {
      return this.topic.updateDestinationCategory(categoryId);
    },

    publish() {
      bootbox.confirm(I18n.t("shared_drafts.confirm_publish"), result => {
        if (result) {
          this.set("publishing", true);
          let destId = this.get("topic.destination_category_id");
          this.topic
            .publish()
            .then(() => {
              this.set("topic.category_id", destId);
            })
            .finally(() => {
              this.set("publishing", false);
            });
        }
      });
    }
  }
});
