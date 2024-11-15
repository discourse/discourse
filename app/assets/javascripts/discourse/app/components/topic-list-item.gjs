import { cached } from "@glimmer/tracking";
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import { getOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import {
  attributeBindings,
  classNameBindings,
  tagName,
} from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";
import $ from "jquery";
import PluginOutlet from "discourse/components/plugin-outlet";
import { createColumns } from "discourse/components/topic-list/dag";
import { topicTitleDecorators } from "discourse/components/topic-title";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import { applyValueTransformer } from "discourse/lib/transformer";
import DiscourseURL, { groupPath } from "discourse/lib/url";
import { RUNTIME_OPTIONS } from "discourse-common/lib/raw-handlebars-helpers";
import { findRawTemplate } from "discourse-common/lib/raw-templates";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export function showEntrance(e) {
  let target = $(e.target);

  if (target.hasClass("posts-map") || target.parents(".posts-map").length > 0) {
    if (target.prop("tagName") !== "A") {
      target = target.find("a");
      if (target.length === 0) {
        target = target.end();
      }
    }

    this.appEvents.trigger("topic-entrance:show", {
      topic: this.topic,
      position: target.offset(),
    });
    return false;
  }
}

export function navigateToTopic(topic, href) {
  const historyStore = getOwner(this).lookup("service:history-store");
  historyStore.set("lastTopicIdViewed", topic.id);

  DiscourseURL.routeTo(href || topic.get("url"));
  return false;
}

// Despite the gjs extension this is the old, hbr-based implementation
@tagName("tr")
@classNameBindings(":topic-list-item", "unboundClassNames", "topic.visited")
@attributeBindings("dataTopicId:data-topic-id", "role", "ariaLevel:aria-level")
export default class TopicListItem extends Component {
  @service currentUser;
  @service historyStore;
  @service messageBus;
  @service router;
  @service site;
  @service siteSettings;
  @service topicTrackingState;

  @alias("topic.id") dataTopicId;

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);
    this.renderTopicListItem();
  }

  // Already-rendered topic is marked as highlighted
  // Ideally this should be a modifier... but we can't do that
  // until this component has its tagName removed.
  @observes("topic.highlight")
  topicHighlightChanged() {
    if (this.topic.highlight) {
      this._highlightIfNeeded();
    }
  }

  @observes("topic.pinned", "expandGloballyPinned", "expandAllPinned")
  renderTopicListItem() {
    const template = findRawTemplate("list/topic-list-item");
    if (template) {
      this.set(
        "topicListItemContents",
        htmlSafe(template(this, RUNTIME_OPTIONS))
      );
      schedule("afterRender", () => {
        if (this.isDestroyed || this.isDestroying) {
          return;
        }
        if (this.selected?.includes(this.topic)) {
          const input = this.element?.querySelector("input.bulk-select");
          if (input) {
            input.checked = true;
          }
        }
        if (this._shouldFocusLastVisited()) {
          const title = this._titleElement();
          if (title) {
            title.addEventListener("focus", this._onTitleFocus);
            title.addEventListener("blur", this._onTitleBlur);
          }
        }
      });
    }
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    if (this.includeUnreadIndicator) {
      this.messageBus.subscribe(this.unreadIndicatorChannel, this.onMessage);
    }

    schedule("afterRender", () => {
      if (this.element && !this.isDestroying && !this.isDestroyed) {
        const rawTopicLink = this.element.querySelector(".raw-topic-link");

        rawTopicLink &&
          topicTitleDecorators.forEach((cb) =>
            cb(this.topic, rawTopicLink, "topic-list-item-title")
          );
      }
    });
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this.messageBus.unsubscribe(this.unreadIndicatorChannel, this.onMessage);

    if (this._shouldFocusLastVisited()) {
      const title = this._titleElement();
      if (title) {
        title.removeEventListener("focus", this._onTitleFocus);
        title.removeEventListener("blur", this._onTitleBlur);
      }
    }
  }

  @bind
  onMessage(data) {
    const nodeClassList = document.querySelector(
      `.indicator-topic-${data.topic_id}`
    ).classList;

    nodeClassList.toggle("read", !data.show_indicator);
  }

  get selected() {
    return this.bulkSelectHelper?.selected;
  }

  @discourseComputed("topic.participant_groups")
  participantGroups(groupNames) {
    if (!groupNames) {
      return [];
    }

    return groupNames.map((name) => {
      return { name, url: groupPath(name) };
    });
  }

  @discourseComputed("topic.id")
  unreadIndicatorChannel(topicId) {
    return `/private-messages/unread-indicator/${topicId}`;
  }

  @discourseComputed("topic.unread_by_group_member")
  unreadClass(unreadByGroupMember) {
    return unreadByGroupMember ? "" : "read";
  }

  @discourseComputed("topic.unread_by_group_member")
  includeUnreadIndicator(unreadByGroupMember) {
    return typeof unreadByGroupMember !== "undefined";
  }

  @discourseComputed
  newDotText() {
    return this.currentUser && this.currentUser.trust_level > 0
      ? ""
      : I18n.t("filters.new.lower_title");
  }

  @discourseComputed("topic", "lastVisitedTopic")
  unboundClassNames(topic, lastVisitedTopic) {
    let classes = [];

    if (topic.get("category")) {
      classes.push("category-" + topic.get("category.fullSlug"));
    }

    if (topic.get("tags")) {
      topic.get("tags").forEach((tag) => classes.push("tag-" + tag));
    }

    if (topic.get("hasExcerpt")) {
      classes.push("has-excerpt");
    }

    if (topic.get("unseen")) {
      classes.push("unseen-topic");
    }

    if (topic.unread_posts) {
      classes.push("unread-posts");
    }

    ["liked", "archived", "bookmarked", "pinned", "closed"].forEach((name) => {
      if (topic.get(name)) {
        classes.push(name);
      }
    });

    if (topic === lastVisitedTopic) {
      classes.push("last-visit");
    }

    return classes.join(" ");
  }

  hasLikes() {
    return this.get("topic.like_count") > 0;
  }

  hasOpLikes() {
    return this.get("topic.op_like_count") > 0;
  }

  @discourseComputed
  expandPinned() {
    const pinned = this.get("topic.pinned");
    if (!pinned) {
      return false;
    }

    if (this.site.mobileView) {
      if (!this.siteSettings.show_pinned_excerpt_mobile) {
        return false;
      }
    } else {
      if (!this.siteSettings.show_pinned_excerpt_desktop) {
        return false;
      }
    }

    if (this.expandGloballyPinned && this.get("topic.pinned_globally")) {
      return true;
    }

    if (this.expandAllPinned) {
      return true;
    }

    return false;
  }

  showEntrance() {
    return showEntrance.call(this, ...arguments);
  }

  click(e) {
    if (e.defaultPrevented) {
      return;
    }

    // new gjs topic-list-item components handle events on their own
    if (e.target.closest(".hbr-ember-outlet")) {
      return;
    }

    const result = this.showEntrance(e);
    if (result === false) {
      return result;
    }

    const topic = this.topic;
    const target = e.target;
    const classList = target.classList;
    if (classList.contains("bulk-select")) {
      this.onBulkSelectToggle(e);
      return;
    }

    if (
      classList.contains("raw-topic-link") ||
      classList.contains("post-activity")
    ) {
      if (wantsNewWindow(e)) {
        return true;
      }
      e.preventDefault();
      return this.navigateToTopic(topic, target.getAttribute("href"));
    }

    // make full row click target on mobile, due to size constraints
    if (
      this.site.mobileView &&
      e.target.matches(
        ".topic-list-data, .main-link, .right, .topic-item-stats, .topic-item-stats__category-tags, .discourse-tags"
      )
    ) {
      if (wantsNewWindow(e)) {
        return true;
      }
      e.preventDefault();
      return this.navigateToTopic(topic, topic.lastUnreadUrl);
    }

    if (
      classList.contains("d-icon-thumbtack") &&
      target.closest("a.topic-status")
    ) {
      this.topic.togglePinnedForUser();
      return false;
    }

    return this.unhandledRowClick(e, topic);
  }

  unhandledRowClick() {}

  @action
  onBulkSelectToggle(event) {
    if (event.target.checked) {
      this.selected.addObject(this.topic);

      if (this.bulkSelectHelper.lastCheckedElementId && event.shiftKey) {
        const bulkSelects = [...document.querySelectorAll("input.bulk-select")];
        const from = bulkSelects.indexOf(event.target);
        const to = bulkSelects.findIndex(
          (el) => el.id === this.bulkSelectHelper.lastCheckedElementId
        );
        const start = Math.min(from, to);
        const end = Math.max(from, to);

        bulkSelects
          .slice(start, end)
          .filter((el) => el.checked !== true)
          .forEach((checkbox) => checkbox.click());
      }

      this.bulkSelectHelper.lastCheckedElementId = event.target.id;
    } else {
      this.selected.removeObject(this.topic);
      this.bulkSelectHelper.lastCheckedElementId = null;
    }
  }

  keyDown(e) {
    if (e.key === "Enter" && e.target.classList.contains("post-activity")) {
      e.preventDefault();
      return this.navigateToTopic(this.topic, e.target.getAttribute("href"));
    }
  }

  navigateToTopic() {
    return navigateToTopic.call(this, ...arguments);
  }

  highlight(opts = { isLastViewedTopic: false }) {
    schedule("afterRender", () => {
      if (!this.element || this.isDestroying || this.isDestroyed) {
        return;
      }

      this.element.classList.add("highlighted");
      this.element.setAttribute(
        "data-is-last-viewed-topic",
        opts.isLastViewedTopic
      );
      this.element.addEventListener("animationend", () => {
        this.element.classList.remove("highlighted");
      });
      if (opts.isLastViewedTopic && this._shouldFocusLastVisited()) {
        this._titleElement()?.focus();
      }
    });
  }

  get isSelected() {
    return this.get("selected")?.includes(this.get("topic"));
  }

  @on("didInsertElement")
  _highlightIfNeeded() {
    // highlight the last topic viewed
    const lastViewedTopicId = this.historyStore.get("lastTopicIdViewed");
    const isLastViewedTopic = lastViewedTopicId === this.topic.id;

    if (isLastViewedTopic) {
      this.historyStore.delete("lastTopicIdViewed");
      this.highlight({ isLastViewedTopic: true });
    } else if (this.get("topic.highlight")) {
      // highlight new topics that have been loaded from the server or the one we just created
      this.set("topic.highlight", false);
      this.highlight();
    }
  }

  @bind
  _onTitleFocus() {
    if (this.element && !this.isDestroying && !this.isDestroyed) {
      this.element.classList.add("selected");
    }
  }

  @bind
  _onTitleBlur() {
    if (this.element && !this.isDestroying && !this.isDestroyed) {
      this.element.classList.remove("selected");
    }
  }

  _shouldFocusLastVisited() {
    return this.site.desktopView && this.focusLastVisitedTopic;
  }

  _titleElement() {
    return this.element.querySelector(".main-link .title");
  }

  @cached
  get columns() {
    const self = this;
    const context = {
      get category() {
        return self.topicTrackingState.get("filterCategory");
      },
      get filter() {
        return self.topicTrackingState.get("filter");
      },
    };

    return applyValueTransformer(
      "topic-list-item-columns",
      createColumns(),
      context
    )
      .resolve()
      .map((entry) => {
        if (entry.value?.item) {
          return htmlSafe(
            rawRenderGlimmer(
              this,
              "th.hbr-ember-outlet",
              <template>
                <@data.component
                  @topic={{@data.topic}}
                  @bulkSelectEnabled={{@data.bulkSelectEnabled}}
                  @onBulkSelectToggle={{@data.onBulkSelectToggle}}
                  @isSelected={{@data.isSelected}}
                  @showTopicPostBadges={{@data.showTopicPostBadges}}
                  @tagsForUser={{@data.tagsForUser}}
                  @hideCategory={{@data.hideCategory}}
                  @onTitleFocus={{@data.onTitleFocus}}
                  @onTitleBlur={{@data.onTitleBlur}}
                  @includeUnreadIndicator={{@data.includeUnreadIndicator}}
                  @unreadClass={{@data.unreadClass}}
                  @newDotText={{@data.newDotText}}
                  @expandPinned={{@data.expandPinned}}
                  @showPosters={{@data.showPosters}}
                  @showLikes={{@data.showLikes}}
                  @showOpLikes={{@data.showOpLikes}}
                />
              </template>,
              {
                component: entry.value.item,
                topic: this.topic,
                bulkSelectEnabled: this.bulkSelectEnabled,
                onBulkSelectToggle: this.onBulkSelectToggle,
                isSelected: this.isSelected,
                showTopicPostBadges: this.showTopicPostBadges,
                tagsForUser: this.tagsForUser,
                hideCategory: this.hideCategory,
                onTitleFocus: this._onTitleFocus,
                onTitleBlur: this._onTitleBlur,
                includeUnreadIndicator: this.includeUnreadIndicator,
                unreadClass: this.unreadClass,
                newDotText: this.newDotText,
                expandPinned: this.expandPinned,
                showPosters: this.showPosters,
                showLikes: this.showLikes,
                showOpLikes: this.showOpLikes,
              }
            )
          );
        }
      });
  }

  <template>
    <PluginOutlet
      @name="above-topic-list-item"
      @outletArgs={{hash topic=this.topic}}
    />
    {{this.topicListItemContents}}
  </template>
}
