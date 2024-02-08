import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import ChangeCategory from "discourse/components/bulk-actions/change-category";
import NotificationLevel from "discourse/components/bulk-actions/notification-level";
import BulkTopicActions from "discourse/components/modal/bulk-topic-actions";
import TopicBulkActions from "discourse/components/modal/topic-bulk-actions";
import i18n from "discourse-common/helpers/i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import ChangeTags from "discourse/components/bulk-actions/change-tags";

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
  currentUser: service(),

  computeContent() {
    let options = [];
    options = options.concat([
      {
        id: "update-category",
        icon: "pencil-alt",
        name: i18n("topic_bulk_actions.update_category.name"),
        description: i18n("topic_bulk_actions.update_category.description"),
      },
      {
        id: "update-notifications",
        icon: "d-regular",
        name: i18n("topic_bulk_actions.update_notifications.name"),
        description: i18n(
          "topic_bulk_actions.update_notifications.description"
        ),
      },
      {
        id: "reset-bump-dates",
        icon: "anchor",
        name: i18n("topic_bulk_actions.reset_bump_dates.name"),
        description: i18n("topic_bulk_actions.reset_bump_dates.description"),
      },
      {
        id: "defer",
        icon: "circle",
        name: i18n("topic_bulk_actions.defer.name"),
        description: i18n("topic_bulk_actions.defer.description"),
        visible: ({ currentUser }) => currentUser.user_option.enable_defer,
      },
      {
        id: "close-topics",
        icon: "lock",
        name: i18n("topic_bulk_actions.close_topics.name"),
      },
      {
        id: "archive-topics",
        icon: "folder",
        name: i18n("topic_bulk_actions.archive_topics.name"),
      },
      {
        id: "unlist-topics",
        icon: "far-eye-slash",
        name: i18n("topic_bulk_actions.unlist_topics.name"),
        visible: ({ topics }) =>
        topics.some((t) => t.visible) &&
        !topics.some((t) => t.isPrivateMessage),
      },
      {
        id: "relist-topics",
        icon: "far-eye",
        name: i18n("topic_bulk_actions.relist_topics.name"),
        visible: ({ topics }) =>
        topics.some((t) => !t.visible) &&
        !topics.some((t) => t.isPrivateMessage),
      },
      {
        id: "append-tags",
        icon: "tag",
        name: i18n("topic_bulk_actions.append_tags.name"),
      },
      {
        id: "replace-tags",
        icon: "tag",
        name: i18n("topic_bulk_actions.replace_tags.name"),
      },
      {
        id: "remove-tags",
        icon: "tag",
        name: i18n("topic_bulk_actions.remove_tags.name"),
      },
      {
        id: "delete-topics",
        icon: "trash-alt",
        name: i18n("topic_bulk_actions.delete_topics.name"),
      },
    ]);

    return [...options].filter(({ visible }) => {
      if (visible) {
        return visible({
          topics: this.bulkSelectHelper.selected,
          // category: this.args.model.category,
          currentUser: this.currentUser,
          // siteSettings: this.siteSettings,
        });
      } else {
        return true;
      }
    });
  },

  @action
  onSelect(id) {
    switch (id) {
      case "update-category":
        // Temporary: just use the existing modal & action
        // this.modal.show(TopicBulkActions, {
        //   model: {
        //     topics: this.bulkSelectHelper.selected,
        //     category: this.category,
        //     refreshClosure: () => this.router.refresh(),
        //     initialAction: "set-component",
        //     initialComponent: ChangeCategory,
        //   },
        // });
        this.modal.show(BulkTopicActions, {
          model: {
            action: "update-category",
            title: i18n("topics.bulk.change_category"),
            bulkSelectHelper: this.bulkSelectHelper,
            refreshClosure: () => this.router.refresh(),
          }
        });
        break;
      case "update-notifications":
        // Temporary: just use the existing modal & action
        // this.modal.show(TopicBulkActions, {
        //   model: {
        //     topics: this.bulkSelectHelper.selected,
        //     category: this.category,
        //     refreshClosure: () => this.router.refresh(),
        //     initialAction: "set-component",
        //     initialComponent: NotificationLevel,
        //   },
        // });
        this.modal.show(BulkTopicActions, {
          model: {
            action: "update-notifications",
            title: i18n("topics.bulk.notification_level"),
            bulkSelectHelper: this.bulkSelectHelper,
            refreshClosure: () => this.router.refresh(),
          }
        });
        break;
      case "close-topics":
        this.modal.show(BulkTopicActions, {
          model: {
            action: "close",
            title: i18n("topics.bulk.close_topics"),
            bulkSelectHelper: this.bulkSelectHelper,
            refreshClosure: () => this.router.refresh(),
            allowSilent: true,
          },
        });
        break;
      case "archive-topics":
        this.modal.show(BulkTopicActions, {
          model: {
            action: "archive",
            title: i18n("topics.bulk.archive_topics"),
            bulkSelectHelper: this.bulkSelectHelper,
            refreshClosure: () => this.router.refresh(),
          },
        });
        break;
      case "unlist-topics":
        this.modal.show(BulkTopicActions, {
          model: {
            action: "unlist",
            title: i18n("topics.bulk.unlist_topics"),
            bulkSelectHelper: this.bulkSelectHelper,
            refreshClosure: () => this.router.refresh(),
          },
        });
        break;
      case "relist-topics":
        this.modal.show(BulkTopicActions, {
          model: {
            action: "relist",
            title: i18n("topics.bulk.relist_topics"),
            bulkSelectHelper: this.bulkSelectHelper,
            refreshClosure: () => this.router.refresh(),
          },
        });
        break;
      case "append-tags":
        this.modal.show(BulkTopicActions, {
          model: {
            action: "append-tags",
            title: i18n("topics.bulk.choose_append_tags"),
            bulkSelectHelper: this.bulkSelectHelper,
            refreshClosure: () => this.router.refresh(),
          },
        });
        break;
      case "replace-tags":
        this.modal.show(BulkTopicActions, {
          model: {
            action: "replace-tags",
            title: i18n("topics.bulk.change_tags"),
            bulkSelectHelper: this.bulkSelectHelper,
            refreshClosure: () => this.router.refresh(),
            initialAction: "set-component",
          },
        });
        break;
      case "remove-tags":
        this.modal.show(BulkTopicActions, {
          model: {
            action: "remove-tags",
            title: i18n("topics.bulk.remove_tags"),
            bulkSelectHelper: this.bulkSelectHelper,
            refreshClosure: () => this.router.refresh(),
          },
        });
        break;
      case "delete-topics":
        this.modal.show(BulkTopicActions, {
          model: {
            action: "delete",
            title: i18n("topics.bulk.delete"),
            bulkSelectHelper: this.bulkSelectHelper,
            refreshClosure: () => this.router.refresh(),
          },
        });
        break;
      case "reset-bump-dates":
        this.modal.show(BulkTopicActions, {
          model: {
            action: "reset-bump-dates",
            title: i18n("topics.bulk.reset_bump_dates"),
            bulkSelectHelper: this.bulkSelectHelper,
            refreshClosure: () => this.router.refresh(),
          },
        });
        break;
      case "defer":
        this.modal.show(BulkTopicActions, {
          model: {
            action: "defer",
            title: i18n("topics.bulk.defer"),
            bulkSelectHelper: this.bulkSelectHelper,
            refreshClosure: () => this.router.refresh(),
          },
        });
        break;
    }
  },
});
