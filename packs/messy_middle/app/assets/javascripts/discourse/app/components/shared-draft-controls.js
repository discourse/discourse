import Component from "@ember/component";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default Component.extend({
  tagName: "",
  dialog: service(),
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
      this.dialog.yesNoConfirm({
        message: I18n.t("shared_drafts.confirm_publish"),
        didConfirm: () => {
          this.set("publishing", true);
          const destinationCategoryId = this.topic.destination_category_id;
          return this.topic
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
        },
      });
    },
  },
});
