import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action, computed } from "@ember/object";
import I18n from "I18n";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import getURL from "discourse-common/lib/get-url";
import { iconHTML } from "discourse-common/lib/icon-library";

export default class MoreTopics extends Component {
  @service site;
  @service moreTopicsPreferenceTracking;
  @service pmTopicTrackingState;
  @service topicTrackingState;
  @service currentUser;

  @action
  rememberTopicListPreference(value) {
    this.moreTopicsPreferenceTracking.updatePreference(value);
  }

  @computed("moreTopicsPreferenceTracking.topicLists")
  get singleList() {
    return this.availableTabs.length === 1;
  }

  @computed("moreTopicsPreferenceTracking.selectedTab")
  get selectedTab() {
    return this.moreTopicsPreferenceTracking.selectedTab;
  }

  @computed("moreTopicsPreferenceTracking.topicLists")
  get availableTabs() {
    return this.moreTopicsPreferenceTracking.topicLists;
  }

  @computed(
    "pmTopicTrackingState.isTracking",
    "pmTopicTrackingState.statesModificationCounter",
    "topicTrackingState.messageCount"
  )
  get browseMoreMessage() {
    return this.args.topic.isPrivateMessage
      ? this._privateMessageBrowseMoreMessage()
      : this._topicBrowseMoreMessage();
  }

  _privateMessageBrowseMoreMessage() {
    const username = this.currentUser.username;
    const suggestedGroupName = this.args.topic.suggested_group_name;
    const inboxFilter = suggestedGroupName ? "group" : "user";

    const unreadCount = this.pmTopicTrackingState.lookupCount("unread", {
      inboxFilter,
      groupName: suggestedGroupName,
    });

    const newCount = this.pmTopicTrackingState.lookupCount("new", {
      inboxFilter,
      groupName: suggestedGroupName,
    });

    if (unreadCount + newCount > 0) {
      const hasBoth = unreadCount > 0 && newCount > 0;

      if (suggestedGroupName) {
        return I18n.messageFormat("user.messages.read_more_group_pm_MF", {
          HAS_UNREAD_AND_NEW: hasBoth,
          UNREAD: unreadCount,
          NEW: newCount,
          username,
          groupName: suggestedGroupName,
          groupLink: this._groupLink(username, suggestedGroupName),
          basePath: getURL(""),
        });
      } else {
        return I18n.messageFormat("user.messages.read_more_personal_pm_MF", {
          HAS_UNREAD_AND_NEW: hasBoth,
          UNREAD: unreadCount,
          NEW: newCount,
          username,
          basePath: getURL(""),
        });
      }
    } else if (suggestedGroupName) {
      return I18n.t("user.messages.read_more_in_group", {
        groupLink: this._groupLink(username, suggestedGroupName),
      });
    } else {
      return I18n.t("user.messages.read_more", {
        basePath: getURL(""),
        username,
      });
    }
  }

  _topicBrowseMoreMessage() {
    let category = this.args.topic.category;

    if (category && category.id === this.site.uncategorized_category_id) {
      category = null;
    }

    let unreadTopics = 0;
    let newTopics = 0;

    if (this.currentUser) {
      unreadTopics = this.topicTrackingState.countUnread();
      newTopics = this.topicTrackingState.countNew();
    }

    if (newTopics + unreadTopics > 0) {
      return I18n.messageFormat("topic.read_more_MF", {
        HAS_UNREAD_AND_NEW: unreadTopics > 0 && newTopics > 0,
        UNREAD: unreadTopics,
        NEW: newTopics,
        HAS_CATEGORY: category ? true : false,
        categoryLink: category ? categoryBadgeHTML(category) : null,
        basePath: getURL(""),
      });
    } else if (category) {
      return I18n.t("topic.read_more_in_category", {
        categoryLink: categoryBadgeHTML(category),
        latestLink: getURL("/latest"),
      });
    } else {
      return I18n.t("topic.read_more", {
        categoryLink: getURL("/categories"),
        latestLink: getURL("/latest"),
      });
    }
  }

  _groupLink(username, groupName) {
    return `<a class="group-link" href="${getURL(
      `/u/${username}/messages/group/${groupName}`
    )}">${iconHTML("users")} ${groupName}</a>`;
  }
}
