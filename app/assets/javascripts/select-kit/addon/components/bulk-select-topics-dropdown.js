import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import ChangeCategory from "discourse/components/bulk-actions/change-category";
import BulkTopicActions from "discourse/components/modal/bulk-topic-actions";
import TopicBulkActions from "discourse/components/modal/topic-bulk-actions";
import i18n from "discourse-common/helpers/i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  classNames: ["bulk-select-topics-dropdown"],
  headerIcon: null,
  showFullTitle: true,
  selectKitOptions: {
    showCaret: true,
    showFullTitle: true,
    none: "select_kit.components.bulk_select_topics_dropdown.title",
  },

  modal: service(),
  router: service(),

  computeContent() {
    let options = [];
    options = options.concat([
      {
        id: "update-category",
        icon: "pencil-alt",
        name: "Update Category",
        description: "Choose the new category for the selected topics",
      },
      {
        id: "close-topics",
        icon: "lock",
        name: "Close Topics",
      },
    ]);
    return options;
  },

  @action
  onSelect(id) {
    switch (id) {
      case "update-category":
        // Temporary: just use the existing modal & action
        this.modal.show(TopicBulkActions, {
          model: {
            topics: this.bulkSelectHelper.selected,
            category: this.category,
            refreshClosure: () => this.router.refresh(),
            initialAction: "set-component",
            initialComponent: ChangeCategory,
          },
        });
        break;
      case "close-topics":
        this.modal.show(BulkTopicActions, {
          model: {
            action: "close",
            title: i18n("topics.bulk.close_topics"),
            topics: this.bulkSelectHelper.selected,
            bulkSelectHelper: this.bulkSelectHelper,
            refreshClosure: () => this.router.refresh(),
            allowSilent: true,
          },
        });
        break;
    }
  },
});
