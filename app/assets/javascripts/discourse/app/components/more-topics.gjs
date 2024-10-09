import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { eq, gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import concatClass from "discourse/helpers/concat-class";
import getURL from "discourse-common/lib/get-url";
import { iconHTML } from "discourse-common/lib/icon-library";
import I18n from "discourse-i18n";

export let registeredTabs = [];

export default class MoreTopics extends Component {
  @service currentUser;
  @service keyValueStore;
  @service pmTopicTrackingState;
  @service site;
  @service topicTrackingState;

  @tracked currentTab = this.tabs[0];

  get tabs() {
    const context = "pm";
    return registeredTabs.filter(
      (tab) => tab.context === context || tab.context === "*"
    );
  }

  // TODO: move this
  get privateMessageBrowseMoreMessage() {
    const suggestedGroupName = this.args.topic.get("suggested_group_name");
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
          username: this.currentUser.username,
          groupName: suggestedGroupName,
          groupLink: this.groupLink(
            this.currentUser.username,
            suggestedGroupName
          ),
          basePath: getURL(""),
        });
      } else {
        return I18n.messageFormat("user.messages.read_more_personal_pm_MF", {
          HAS_UNREAD_AND_NEW: hasBoth,
          UNREAD: unreadCount,
          NEW: newCount,
          username: this.currentUser.username,
          basePath: getURL(""),
        });
      }
    } else if (suggestedGroupName) {
      return I18n.t("user.messages.read_more_in_group", {
        groupLink: this.groupLink(
          this.currentUser.username,
          suggestedGroupName
        ),
      });
    } else {
      return I18n.t("user.messages.read_more", {
        basePath: getURL(""),
        username: this.currentUser.username,
      });
    }
  }

  // TODO: move this
  get topicBrowseMoreMessage() {
    let category = this.args.topic.get("category");

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
        HAS_CATEGORY: !!category,
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

  groupLink(username, groupName) {
    return `<a class="group-link" href="${getURL(
      `/u/${username}/messages/group/${groupName}`
    )}">${iconHTML("users")} ${groupName}</a>`;
  }

  @action
  selectTab(tab) {
    this.currentTab = tab;
  }

  <template>
    <div class="more-topics__container">
      {{#if (gt this.tabs.length 1)}}
        <div class="row">
          <ul class="nav nav-pills">
            {{#each this.tabs as |tab|}}
              <li>
                <DButton
                  @action={{fn this.selectTab tab}}
                  @translatedLabel={{tab.name}}
                  @translatedTitle={{tab.name}}
                  @icon={{tab.icon}}
                  class={{if (eq tab.id this.currentTab.id) "active"}}
                />
              </li>
            {{/each}}
          </ul>
        </div>
      {{/if}}

      {{#if this.currentTab}}
        <div
          class={{concatClass
            "more-topics__lists"
            (if (eq this.tabs.length 1) "single-list")
          }}
        >
          <this.currentTab.component @topic={{@topic}} />
        </div>

        {{#if @topic.suggestedTopics.length}}
          <h3 class="more-topics__browse-more">
            {{#if @topic.isPrivateMessage}}
              {{htmlSafe this.privateMessageBrowseMoreMessage}}
            {{else}}
              {{htmlSafe this.topicBrowseMoreMessage}}
            {{/if}}
          </h3>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
