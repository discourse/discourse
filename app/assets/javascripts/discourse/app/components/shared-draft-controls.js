import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

@tagName("")
export default class SharedDraftControls extends Component {
  @service dialog;

  publishing = false;

  @discourseComputed("topic.destination_category_id")
  validCategory(destCatId) {
    return destCatId && destCatId !== this.site.shared_drafts_category_id;
  }

  @action
  updateDestinationCategory(categoryId) {
    return this.topic.updateDestinationCategory(categoryId);
  }

  @action
  publish() {
    this.dialog.yesNoConfirm({
      message: i18n("shared_drafts.confirm_publish"),
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
  }
}
