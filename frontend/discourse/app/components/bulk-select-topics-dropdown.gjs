import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import BulkTopicActions, {
  addBulkDropdownAction,
} from "discourse/components/modal/bulk-topic-actions";
import DismissNew from "discourse/components/modal/dismiss-new";
import DismissReadModal from "discourse/components/modal/dismiss-read";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const _customButtons = [];

export function addBulkDropdownButton(opts) {
  _customButtons.push({
    id: opts.id,
    icon: opts.icon,
    name: i18n(opts.label),
    translationKey: opts.label,
    visible: opts.visible,
    class: opts.class,
    setComponent: opts.actionType !== "performAndRefresh",
  });
  addBulkDropdownAction(opts.id, opts.action);
}

export default class BulkSelectTopicsDropdown extends Component {
  @service router;
  @service modal;
  @service currentUser;
  @service siteSettings;

  get buttons() {
    let options = [
      {
        id: "dismiss-unread",
        icon: "check",
        name: i18n("topic_bulk_actions.dismiss.name"),
        visible: ({ router }) => router.currentRouteName === "discovery.unread",
        action: () =>
          this.modal.show(DismissReadModal, {
            model: {
              title: "topics.bulk.dismiss_read_with_selected",
              count: this.args.bulkSelectHelper.selected.length,
              dismissRead: (dismissTopics) => this.dismissRead(dismissTopics),
            },
          }),
      },
      {
        id: "dismiss-new",
        icon: "check",
        name: i18n("topic_bulk_actions.dismiss.name"),
        visible: ({ router }) => router.currentRouteName === "discovery.new",
        action: () =>
          this.modal.show(DismissNew, {
            model: {
              selectedTopics: this.args.bulkSelectHelper.selected,
              dismissCallback: (dismissTopics) =>
                this.dismissRead(dismissTopics),
            },
          }),
      },
      {
        id: "update-category",
        icon: "pencil",
        name: i18n("topic_bulk_actions.update_category.name"),
        visible: ({ topics }) => {
          return !topics.some((t) => t.isPrivateMessage);
        },
        action: () =>
          this.showBulkTopicActionsModal("update-category", "change_category", {
            allowSilent: true,
            description: i18n(`topic_bulk_actions.update_category.description`),
          }),
      },
      {
        id: "update-notifications",
        icon: "d-regular",
        name: i18n("topic_bulk_actions.update_notifications.name"),
        action: () =>
          this.showBulkTopicActionsModal(
            "update-notifications",
            "notification_level",
            {
              description: i18n(
                `topic_bulk_actions.update_notifications.description`
              ),
            }
          ),
      },
      {
        id: "reset-bump-dates",
        icon: "anchor",
        name: i18n("topic_bulk_actions.reset_bump_dates.name"),
        action: () =>
          this.showBulkTopicActionsModal(
            "reset-bump-dates",
            "reset_bump_dates",
            {
              description: i18n(
                `topic_bulk_actions.reset_bump_dates.description`
              ),
            }
          ),
      },
      {
        id: "defer",
        icon: "circle",
        name: i18n("topic_bulk_actions.defer.name"),
        visible: ({ currentUser }) => currentUser.user_option.enable_defer,
        action: () =>
          this.showBulkTopicActionsModal("defer", "defer", {
            description: i18n(`topic_bulk_actions.defer.description`),
          }),
      },
      {
        id: "close-topics",
        icon: "topic.closed",
        name: i18n("topic_bulk_actions.close_topics.name"),
        action: () =>
          this.showBulkTopicActionsModal("close", "close_topics", {
            allowSilent: true,
          }),
      },
      {
        id: "archive-topics",
        icon: "folder",
        name: i18n("topic_bulk_actions.archive_topics.name"),
        visible: ({ topics }) => !topics.some((t) => t.isPrivateMessage),
        action: () =>
          this.showBulkTopicActionsModal("archive", "archive_topics"),
      },
      {
        id: "archive-messages",
        icon: "box-archive",
        name: i18n("topic_bulk_actions.archive_messages.name"),
        visible: ({ topics }) => topics.every((t) => t.isPrivateMessage),
        action: () =>
          this.showBulkTopicActionsModal(
            "archive_messages",
            "archive_messages"
          ),
      },
      {
        id: "move-messages-to-inbox",
        icon: "envelope",
        name: i18n("topic_bulk_actions.move_messages_to_inbox.name"),
        visible: ({ topics }) => topics.every((t) => t.isPrivateMessage),
        action: () =>
          this.showBulkTopicActionsModal(
            "move_messages_to_inbox",
            "move_messages_to_inbox"
          ),
      },
      {
        id: "unlist-topics",
        icon: "far-eye-slash",
        name: i18n("topic_bulk_actions.unlist_topics.name"),
        visible: ({ topics }) =>
          topics.some((t) => t.visible) &&
          !topics.some((t) => t.isPrivateMessage),
        action: () => this.showBulkTopicActionsModal("unlist", "unlist_topics"),
      },
      {
        id: "relist-topics",
        icon: "far-eye",
        name: i18n("topic_bulk_actions.relist_topics.name"),
        visible: ({ topics }) =>
          topics.some((t) => !t.visible) &&
          !topics.some((t) => t.isPrivateMessage),
        action: () => this.showBulkTopicActionsModal("relist", "relist_topics"),
      },
      {
        id: "append-tags",
        icon: "tag",
        name: i18n("topic_bulk_actions.append_tags.name"),
        visible: ({ currentUser, siteSettings }) =>
          siteSettings.tagging_enabled && currentUser.canManageTopic,
        action: () =>
          this.showBulkTopicActionsModal("append-tags", "choose_append_tags"),
      },
      {
        id: "replace-tags",
        icon: "tag",
        name: i18n("topic_bulk_actions.replace_tags.name"),
        visible: ({ currentUser, siteSettings }) =>
          siteSettings.tagging_enabled && currentUser.canManageTopic,
        action: () =>
          this.showBulkTopicActionsModal("replace-tags", "change_tags"),
      },
      {
        id: "remove-tags",
        icon: "tag",
        name: i18n("topic_bulk_actions.remove_tags.name"),
        visible: ({ currentUser, siteSettings }) =>
          siteSettings.tagging_enabled && currentUser.canManageTopic,
        action: () =>
          this.showBulkTopicActionsModal("remove-tags", "remove_tags"),
      },
      {
        id: "delete-topics",
        icon: "trash-can",
        name: i18n("topic_bulk_actions.delete_topics.name"),
        visible: ({ currentUser }) => currentUser.staff,
        action: () => this.showBulkTopicActionsModal("delete", "delete"),
      },
    ];

    const customButtons = _customButtons.map((button) => ({
      ...button,
      action: () =>
        this.showBulkTopicActionsModal(button.id, button.translationKey, {
          custom: true,
          setComponent: button.setComponent,
          translationKey: button.translationKey,
        }),
    }));

    return [...options, ...customButtons].filter(({ visible }) => {
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
    let description = opts.description;
    let translatedTitle;

    if (opts.allowSilent === true) {
      allowSilent = true;
    }
    if (opts.custom === true) {
      translatedTitle = i18n(opts.translationKey || title);
      initialActionLabel = actionName;
      if (opts.setComponent === true) {
        initialAction = "set-component";
      }
    } else {
      translatedTitle = i18n(`topics.bulk.${title}`);
    }

    this.modal.show(BulkTopicActions, {
      model: {
        action: actionName,
        title: translatedTitle,
        description,
        bulkSelectHelper: this.args.bulkSelectHelper,
        refreshClosure: () => this.args.afterBulkActionComplete(),
        allowSilent,
        initialAction,
        initialActionLabel,
      },
    });
  }

  @action
  async onSelect(button) {
    await this.dMenu.close();

    await button?.action?.();
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
                @action={{fn this.onSelect button}}
              />
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
