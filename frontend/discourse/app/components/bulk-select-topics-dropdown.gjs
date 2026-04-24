import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import BulkTopicActions, {
  addBulkDropdownAction,
} from "discourse/components/modal/bulk-topic-actions";
import DismissReadModal from "discourse/components/modal/dismiss-read";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import Topic from "discourse/models/topic";
import { i18n } from "discourse-i18n";

const _customButtons = [];
const _customOnSelection = {};

export function addBulkDropdownButton(opts) {
  _customButtons.push({
    id: opts.id,
    icon: opts.icon,
    name: i18n(opts.label),
    visible: opts.visible,
    class: opts.class,
  });
  addBulkDropdownAction(opts.id, opts.action);
  const actionOpts = {
    label: opts.label,
    setComponent: true,
  };
  if (opts.actionType === "performAndRefresh") {
    actionOpts.setComponent = false;
  }
  if (opts.description) {
    actionOpts.description = opts.description;
  }
  if (opts.confirmButtonTranslationKey) {
    actionOpts.confirmButtonTranslationKey = opts.confirmButtonTranslationKey;
  }
  _customOnSelection[opts.id] = actionOpts;
}

export default class BulkSelectTopicsDropdown extends Component {
  @service router;
  @service modal;
  @service currentUser;
  @service siteSettings;
  @service toasts;

  get buttons() {
    let options = [
      {
        id: "dismiss-unread",
        icon: "check",
        name: i18n("topic_bulk_actions.dismiss.name"),
        visible: ({ router }) => router.currentRouteName === "discovery.unread",
      },
      {
        id: "dismiss-new",
        icon: "check",
        name: i18n("topic_bulk_actions.dismiss.name"),
        visible: ({ router }) => router.currentRouteName === "discovery.new",
      },
      {
        id: "update-category",
        icon: "pencil",
        name: i18n("topic_bulk_actions.update_category.name"),
        visible: ({ topics }) => {
          return !topics.some((t) => t.isPrivateMessage);
        },
      },
      {
        id: "update-notifications",
        icon: "d-regular",
        name: i18n("topic_bulk_actions.update_notifications.name"),
      },
      {
        id: "reset-bump-dates",
        icon: "anchor",
        name: i18n("topic_bulk_actions.reset_bump_dates.name"),
      },
      {
        id: "defer",
        icon: "circle",
        name: i18n("topic_bulk_actions.defer.name"),
        visible: ({ currentUser }) => currentUser.user_option.enable_defer,
      },
      {
        id: "close-topics",
        icon: "topic.closed",
        name: i18n("topic_bulk_actions.close_topics.name"),
      },
      {
        id: "manage-tags",
        icon: "tag",
        name: i18n("topic_bulk_actions.manage_tags.name"),
        visible: ({ currentUser, siteSettings }) =>
          siteSettings.tagging_enabled && currentUser.canManageTopic,
      },
      {
        id: "pin-topics",
        icon: "thumbtack",
        name: i18n("topic_bulk_actions.pin_topics.name"),
        visible: ({ topics }) => !topics.some((t) => t.isPrivateMessage),
      },
      {
        id: "unpin-topics",
        icon: "thumbtack",
        name: i18n("topic_bulk_actions.unpin_topics.name"),
        visible: ({ topics }) =>
          topics.some((t) => t.pinned || t.unpinned) &&
          !topics.some((t) => t.isPrivateMessage),
      },
      {
        id: "archive-topics",
        icon: "folder",
        name: i18n("topic_bulk_actions.archive_topics.name"),
        visible: ({ topics }) => !topics.some((t) => t.isPrivateMessage),
      },
      {
        id: "archive-messages",
        icon: "box-archive",
        name: i18n("topic_bulk_actions.archive_messages.name"),
        visible: ({ topics }) => topics.every((t) => t.isPrivateMessage),
      },
      {
        id: "move-messages-to-inbox",
        icon: "envelope",
        name: i18n("topic_bulk_actions.move_messages_to_inbox.name"),
        visible: ({ topics }) => topics.every((t) => t.isPrivateMessage),
      },
      {
        id: "convert-to-public-topic",
        icon: "comments",
        name: i18n("topic_bulk_actions.convert_to_public_topic.name"),
        visible: ({ topics, currentUser }) =>
          currentUser.staff && topics.every((t) => t.isPrivateMessage),
      },
      {
        id: "convert-to-private-message",
        icon: "envelope",
        name: i18n("topic_bulk_actions.convert_to_private_message.name"),
        visible: ({ topics, currentUser }) =>
          currentUser.staff && topics.every((t) => !t.isPrivateMessage),
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
        id: "delete-topics",
        icon: "trash-can",
        name: i18n("topic_bulk_actions.delete_topics.name"),
        visible: ({ currentUser }) => currentUser.staff,
      },
    ];

    const excludedButtonIds = this.args.excludedButtonIds || [];
    const baseOptions = [...options, ..._customButtons].filter(
      (button) => !excludedButtonIds.includes(button.id)
    );
    const extraButtons = this.args.extraButtons || [];

    return [...baseOptions, ...extraButtons].filter(({ visible }) => {
      if (visible) {
        return visible({
          topics: this.args.bulkSelectHelper.selected,
          currentUser: this.currentUser,
          siteSettings: this.siteSettings,
          router: this.router,
        });
      } else {
        return true;
      }
    });
  }

  showBulkTopicActionsModal(actionName, title, opts = {}) {
    let allowSilent = false;
    let initialAction = null;
    let initialActionLabel = null;
    let description = null;
    let confirmButtonTranslationKey = null;
    if (opts.allowSilent === true) {
      allowSilent = true;
    }
    if (opts.custom === true) {
      title = i18n(_customOnSelection[actionName].label);
      initialActionLabel = actionName;
      if (opts.setComponent === true) {
        initialAction = "set-component";
      }
      if (_customOnSelection[actionName].description) {
        description = i18n(_customOnSelection[actionName].description);
      }
      if (_customOnSelection[actionName].confirmButtonTranslationKey) {
        confirmButtonTranslationKey =
          _customOnSelection[actionName].confirmButtonTranslationKey;
      }
    } else {
      title = i18n(`topics.bulk.${title}`);
    }
    if (opts.description) {
      description = opts.description;
    }
    if (opts.confirmButtonTranslationKey) {
      confirmButtonTranslationKey = opts.confirmButtonTranslationKey;
    }

    this.modal.show(BulkTopicActions, {
      model: {
        action: actionName,
        title,
        description,
        confirmButtonTranslationKey,
        bulkSelectHelper: this.args.bulkSelectHelper,
        refreshClosure: () => this.args.afterBulkActionComplete(),
        allowSilent,
        initialAction,
        initialActionLabel,
        showFooter: opts.showFooter !== false,
      },
    });
  }

  @action
  async onSelect(actionId) {
    await this.dMenu.close();

    switch (actionId) {
      case "dismiss-unread":
        this.modal.show(DismissReadModal, {
          model: {
            title: "topics.bulk.dismiss_read_with_selected",
            count: this.args.bulkSelectHelper.selected.length,
            dismissRead: (dismissTopics) => this.dismissRead(dismissTopics),
          },
        });
        break;
      case "dismiss-new":
        this.args.bulkSelectHelper.onResetNew?.();
        break;
      case "update-category":
        this.showBulkTopicActionsModal(actionId, "change_category", {
          allowSilent: true,
          description: i18n(`topic_bulk_actions.update_category.description`),
          confirmButtonTranslationKey: "topics.bulk.confirm_update_topics",
        });
        break;
      case "update-notifications":
        this.showBulkTopicActionsModal(actionId, "notification_level", {
          description: i18n(
            `topic_bulk_actions.update_notifications.description`
          ),
          confirmButtonTranslationKey: "topics.bulk.confirm_update_topics",
        });
        break;
      case "close-topics":
        this.showBulkTopicActionsModal("close", "close_topics", {
          allowSilent: true,
          description: i18n(`topic_bulk_actions.close_topics.description`),
          confirmButtonTranslationKey: "topics.bulk.confirm_close_topics",
        });
        break;
      case "archive-topics":
        this.showBulkTopicActionsModal("archive", "archive_topics", {
          description: i18n(`topic_bulk_actions.archive_topics.description`),
          confirmButtonTranslationKey: "topics.bulk.confirm_archive_topics",
        });
        break;
      case "archive-messages":
        this.showBulkTopicActionsModal("archive_messages", "archive_messages", {
          confirmButtonTranslationKey: "topics.bulk.confirm_archive_messages",
        });
        break;
      case "move-messages-to-inbox":
        this.showBulkTopicActionsModal(
          "move_messages_to_inbox",
          "move_messages_to_inbox",
          {
            confirmButtonTranslationKey: "topics.bulk.confirm_move_to_inbox",
          }
        );
        break;
      case "convert-to-public-topic":
      case "convert-to-private-message":
        const actionName = actionId.replaceAll("-", "_");
        this.showBulkTopicActionsModal(actionId, actionName, {
          allowSilent: true,
          description: i18n(`topic_bulk_actions.${actionName}.description`),
          confirmButtonTranslationKey: "topics.bulk.confirm_update_topics",
        });
        break;
      case "unlist-topics":
        this.showBulkTopicActionsModal("unlist", "unlist_topics", {
          description: i18n(`topic_bulk_actions.unlist_topics.description`),
          confirmButtonTranslationKey: "topics.bulk.confirm_unlist_topics",
        });
        break;
      case "relist-topics":
        this.showBulkTopicActionsModal("relist", "relist_topics", {
          confirmButtonTranslationKey: "topics.bulk.confirm_relist_topics",
        });
        break;
      case "manage-tags":
        this.showBulkTopicActionsModal(actionId, "manage_tags", {
          confirmButtonTranslationKey: "topics.bulk.confirm_apply_to_topics",
        });
        break;
      case "delete-topics":
        this.showBulkTopicActionsModal("delete", "delete", {
          description: i18n(`topic_bulk_actions.delete_topics.description`),
          confirmButtonTranslationKey: "topics.bulk.confirm_delete_topics",
        });
        break;
      case "reset-bump-dates":
        this.showBulkTopicActionsModal(actionId, "reset_bump_dates", {
          description: i18n(`topic_bulk_actions.reset_bump_dates.description`),
          confirmButtonTranslationKey: "topics.bulk.confirm_update_topics",
        });
        break;
      case "pin-topics":
        this.showBulkTopicActionsModal("pin", "pin_topics", {
          showFooter: false,
        });
        break;
      case "unpin-topics":
        this.showBulkTopicActionsModal("unpin", "unpin_topics", {
          description: i18n("topic_bulk_actions.unpin_topics.description"),
          confirmButtonTranslationKey: "topics.bulk.confirm_unpin_topics",
        });
        break;
      case "defer":
        this.deferTopics();
        break;
      default:
        if (_customOnSelection[actionId]) {
          this.showBulkTopicActionsModal(
            actionId,
            _customOnSelection[actionId].label,
            {
              custom: true,
              setComponent: _customOnSelection[actionId].setComponent,
            }
          );
          return;
        }

        if (this.args.onAction) {
          this.args.onAction(actionId);
        }
    }
  }

  @action
  async deferTopics() {
    try {
      await Topic.bulkOperation(
        this.args.bulkSelectHelper.selected,
        { type: "destroy_post_timing" },
        {}
      );
      this.args.afterBulkActionComplete?.();
      this.args.bulkSelectHelper.toggleBulkSelect();
      this.toasts.success({
        duration: "short",
        data: { message: i18n("topics.bulk.completed") },
      });
    } catch {
      this.toasts.error({
        duration: "short",
        data: { message: i18n("generic_error") },
      });
    }
  }

  dismissRead(stopTracking) {
    this.args.bulkSelectHelper.dismissRead(stopTracking ? "topics" : "posts");
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  <template>
    <DMenu
      @modalForMobile={{true}}
      @autofocus={{true}}
      @identifier="bulk-select-topics-dropdown"
      @onRegisterApi={{this.onRegisterApi}}
      @triggerClass="btn-default"
    >
      <:trigger>
        <span class="d-button-label">
          {{i18n "select_kit.components.bulk_select_topics_dropdown.title"}}
        </span>
        {{icon "angle-down"}}
      </:trigger>

      <:content>
        <DropdownMenu as |dropdown|>
          {{#each this.buttons as |button|}}
            <dropdown.item>
              <DButton
                @translatedLabel={{button.name}}
                @icon={{button.icon}}
                class={{concatClass "btn-transparent" button.id button.class}}
                @action={{fn this.onSelect button.id}}
              />
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
