import Component from "@ember/component";
import I18n from "I18n";
import bootbox from "bootbox";
import discourseComputed from "discourse-common/utils/decorators";

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
      bootbox.confirm(I18n.t("shared_drafts.confirm_publish"), (result) => {
        if (result) {
          this.set("publishing", true);
          const destinationCategoryId = this.topic.destination_category_id;
          this.topic
            .publish()
            .then(() => {
              this.topic.setProperties({
                category_id: destinationCategoryId,
                destination_category_id: undefined,
                is_shared_draft: false,
              });
            })
            .finally(() => {
              this.set("publishing", false);
            });
        }
      });
    },
  },
});
