import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import I18n from "I18n";
import { Promise } from "rsvp";
import Topic from "discourse/models/topic";
import ChangeCategory from "../bulk-actions/change-category";
import NotificationLevel from "../bulk-actions/notification-level";
import ChangeTags from "../bulk-actions/change-tags";
import AppendTags from "../bulk-actions/append-tags";
import { getOwner } from "discourse-common/lib/get-owner";

const _customButtons = [];

export function _addBulkButton(opts) {
  _customButtons.push({
    label: opts.label,
    icon: opts.icon,
    class: opts.class,
    visible: opts.visible,
    action: opts.action,
  });
}

export function clearBulkButtons() {
  _customButtons.length = 0;
}

// Modal for performing bulk actions on topics
export default class TopicBulkActions extends Component {
  @service currentUser;
  @service siteSettings;
  @service dialog;

  @tracked loading = false;
  @tracked showProgress = false;
  @tracked processedTopicCount = 0;
  @tracked activeComponent = null;

  defaultButtons = [
    {
      label: "topics.bulk.change_category",
      icon: "pencil-alt",
      class: "btn-default",
      visible: ({ topics }) => !topics.some((t) => t.isPrivateMessage),
      action({ setComponent }) {
        setComponent(ChangeCategory);
      },
    },
    {
      label: "topics.bulk.close_topics",
      icon: "lock",
      class: "btn-default bulk-actions__close-topics",
      visible: ({ topics }) => !topics.some((t) => t.isPrivateMessage),
      action({ forEachPerformed }) {
        forEachPerformed({ type: "close" }, (t) => t.set("closed", true));
      },
    },
    {
      label: "topics.bulk.archive_topics",
      icon: "folder",
      class: "btn-default",
      visible: ({ topics }) => !topics.some((t) => t.isPrivateMessage),
      action({ forEachPerformed }) {
        forEachPerformed({ type: "archive" }, (t) => t.set("archived", true));
      },
    },
    {
      label: "topics.bulk.archive_topics",
      icon: "folder",
      class: "btn-default",
      visible: ({ topics }) => topics.some((t) => t.isPrivateMessage),
      action: ({ performAndRefresh }) => {
        const userPrivateMessages = getOwner(this).lookup(
          "controller:user-private-messages"
        );
        let params = { type: "archive_messages" };

        if (userPrivateMessages.isGroup) {
          params.group = userPrivateMessages.groupFilter;
        }

        performAndRefresh(params);
      },
    },
    {
      label: "topics.bulk.move_messages_to_inbox",
      icon: "folder",
      class: "btn-default",
      visible: ({ topics }) => topics.some((t) => t.isPrivateMessage),
      action: ({ performAndRefresh }) => {
        const userPrivateMessages = getOwner(this).lookup(
          "controller:user-private-messages"
        );
        let params = { type: "move_messages_to_inbox" };

        if (userPrivateMessages.isGroup) {
          params.group = userPrivateMessages.groupFilter;
        }

        performAndRefresh(params);
      },
    },
    {
      label: "topics.bulk.notification_level",
      icon: "d-regular",
      class: "btn-default",
      action({ setComponent }) {
        setComponent(NotificationLevel);
      },
    },
    {
      label: "topics.bulk.defer",
      icon: "circle",
      class: "btn-default",
      visible: ({ currentUser }) => currentUser.user_option.enable_defer,
      action({ performAndRefresh }) {
        performAndRefresh({ type: "destroy_post_timing" });
      },
    },
    {
      label: "topics.bulk.unlist_topics",
      icon: "far-eye-slash",
      class: "btn-default",
      visible: ({ topics }) =>
        topics.some((t) => t.visible) &&
        !topics.some((t) => t.isPrivateMessage),
      action({ forEachPerformed }) {
        forEachPerformed({ type: "unlist" }, (t) => t.set("visible", false));
      },
    },
    {
      label: "topics.bulk.relist_topics",
      icon: "far-eye",
      class: "btn-default",
      visible: ({ topics }) =>
        topics.some((t) => !t.visible) &&
        !topics.some((t) => t.isPrivateMessage),
      action({ forEachPerformed }) {
        forEachPerformed({ type: "relist" }, (t) => t.set("visible", true));
      },
    },
    {
      label: "topics.bulk.reset_bump_dates",
      icon: "anchor",
      class: "btn-default",
      visible: ({ currentUser }) => currentUser.canManageTopic,
      action({ performAndRefresh }) {
        performAndRefresh({ type: "reset_bump_dates" });
      },
    },
    {
      label: "topics.bulk.change_tags",
      icon: "tag",
      class: "btn-default",
      visible: ({ currentUser, siteSettings }) =>
        siteSettings.tagging_enabled && currentUser.canManageTopic,
      action({ setComponent }) {
        setComponent(ChangeTags);
      },
    },
    {
      label: "topics.bulk.append_tags",
      icon: "tag",
      class: "btn-default",
      visible: ({ currentUser, siteSettings }) =>
        siteSettings.tagging_enabled && currentUser.canManageTopic,
      action({ setComponent }) {
        setComponent(AppendTags);
      },
    },
    {
      label: "topics.bulk.remove_tags",
      icon: "tag",
      class: "btn-default",
      visible: ({ currentUser, siteSettings }) =>
        siteSettings.tagging_enabled && currentUser.canManageTopic,
      action: ({ performAndRefresh, topics }) => {
        this.dialog.deleteConfirm({
          message: I18n.t("topics.bulk.confirm_remove_tags", {
            count: topics.length,
          }),
          didConfirm: () => performAndRefresh({ type: "remove_tags" }),
        });
      },
    },
    {
      label: "topics.bulk.delete",
      icon: "trash-alt",
      class: "btn-danger delete-topics",
      visible: ({ currentUser }) => currentUser.staff,
      action({ performAndRefresh }) {
        performAndRefresh({ type: "delete" });
      },
    },
  ];

  get buttons() {
    return [...this.defaultButtons, ..._customButtons].filter(({ visible }) => {
      if (visible) {
        return visible({
          topics: this.args.model.topics,
          category: this.args.model.category,
          currentUser: this.currentUser,
          siteSettings: this.siteSettings,
        });
      } else {
        return true;
      }
    });
  }

  async perform(operation) {
    this.loading = true;

    if (this.args.model.topics.length > 20) {
      this.showProgress = true;
    }

    try {
      return this._processChunks(operation);
    } catch {
      this.dialog.alert(I18n.t("generic_error"));
    } finally {
      this.loading = false;
      this.processedTopicCount = 0;
      this.showProgress = false;
    }
  }

  _generateTopicChunks(allTopics) {
    let startIndex = 0;
    const chunkSize = 30;
    const chunks = [];

    while (startIndex < allTopics.length) {
      const topics = allTopics.slice(startIndex, startIndex + chunkSize);
      chunks.push(topics);
      startIndex += chunkSize;
    }

    return chunks;
  }

  _processChunks(operation) {
    const allTopics = this.args.model.topics;
    const topicChunks = this._generateTopicChunks(allTopics);
    const topicIds = [];

    const tasks = topicChunks.map((topics) => async () => {
      const result = await Topic.bulkOperation(topics, operation);
      this.processedTopicCount = this.processedTopicCount + topics.length;
      return result;
    });

    return new Promise((resolve, reject) => {
      const resolveNextTask = async () => {
        if (tasks.length === 0) {
          const topics = topicIds.map((id) => allTopics.findBy("id", id));
          return resolve(topics);
        }

        const task = tasks.shift();

        try {
          const result = await task();
          if (result?.topic_ids) {
            topicIds.push(...result.topic_ids);
          }
          resolveNextTask();
        } catch {
          reject();
        }
      };

      resolveNextTask();
    });
  }

  @action
  setComponent(component) {
    this.activeComponent = component;
  }

  @action
  async forEachPerformed(operation, cb) {
    const topics = await this.perform(operation);

    if (topics) {
      topics.forEach(cb);
      this.args.model.refreshClosure?.();
      this.args.closeModal();
    }
  }

  @action
  async performAndRefresh(operation) {
    await this.perform(operation);

    this.args.model.refreshClosure?.();
    this.args.closeModal();
  }
}
