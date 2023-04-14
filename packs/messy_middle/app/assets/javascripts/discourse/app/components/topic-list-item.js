import discourseComputed, {
  bind,
  observes,
} from "discourse-common/utils/decorators";
import Component from "@ember/component";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import { RUNTIME_OPTIONS } from "discourse-common/lib/raw-handlebars-helpers";
import { alias } from "@ember/object/computed";
import { findRawTemplate } from "discourse-common/lib/raw-templates";
import { on } from "@ember/object/evented";
import { schedule } from "@ember/runloop";
import { topicTitleDecorators } from "discourse/components/topic-title";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { htmlSafe } from "@ember/template";

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
  this.appEvents.trigger("header:update-topic", topic);
  DiscourseURL.routeTo(href || topic.get("url"));
  return false;
}

export default Component.extend({
  tagName: "tr",
  classNameBindings: [":topic-list-item", "unboundClassNames", "topic.visited"],
  attributeBindings: ["data-topic-id", "role", "ariaLevel:aria-level"],
  "data-topic-id": alias("topic.id"),

  didReceiveAttrs() {
    this._super(...arguments);
    this.renderTopicListItem();
  },

  @observes("topic.pinned")
  renderTopicListItem() {
    const template = findRawTemplate("list/topic-list-item");
    if (template) {
      this.set(
        "topicListItemContents",
        htmlSafe(template(this, RUNTIME_OPTIONS))
      );
      schedule("afterRender", () => {
        if (this.selected && this.selected.includes(this.topic)) {
          this.element.querySelector("input.bulk-select").checked = true;
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
  },

  didInsertElement() {
    this._super(...arguments);

    if (this.includeUnreadIndicator) {
      this.messageBus.subscribe(this.unreadIndicatorChannel, this.onMessage);
    }

    schedule("afterRender", () => {
      if (this.element && !this.isDestroying && !this.isDestroyed) {
        const rawTopicLink = this.element.querySelector(".raw-topic-link");

        rawTopicLink &&
          topicTitleDecorators?.forEach((cb) =>
            cb(this.topic, rawTopicLink, "topic-list-item-title")
          );
      }
    });
  },

  willDestroyElement() {
    this._super(...arguments);

    this.messageBus.unsubscribe(this.unreadIndicatorChannel, this.onMessage);

    if (this._shouldFocusLastVisited()) {
      const title = this._titleElement();
      if (title) {
        title.removeEventListener("focus", this._onTitleFocus);
        title.removeEventListener("blur", this._onTitleBlur);
      }
    }
  },

  @bind
  onMessage(data) {
    const nodeClassList = document.querySelector(
      `.indicator-topic-${data.topic_id}`
    ).classList;

    nodeClassList.toggle("read", !data.show_indicator);
  },

  @discourseComputed("topic.id")
  unreadIndicatorChannel(topicId) {
    return `/private-messages/unread-indicator/${topicId}`;
  },

  @discourseComputed("topic.unread_by_group_member")
  unreadClass(unreadByGroupMember) {
    return unreadByGroupMember ? "" : "read";
  },

  @discourseComputed("topic.unread_by_group_member")
  includeUnreadIndicator(unreadByGroupMember) {
    return typeof unreadByGroupMember !== "undefined";
  },

  @discourseComputed
  newDotText() {
    return this.currentUser && this.currentUser.trust_level > 0
      ? ""
      : I18n.t("filters.new.lower_title");
  },

  @discourseComputed("topic", "lastVisitedTopic")
  unboundClassNames(topic, lastVisitedTopic) {
    let classes = [];

    if (topic.get("category")) {
      classes.push("category-" + topic.get("category.fullSlug"));
    }

    if (topic.get("tags")) {
      topic.get("tags").forEach((tagName) => classes.push("tag-" + tagName));
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
  },

  hasLikes() {
    return this.get("topic.like_count") > 0;
  },

  hasOpLikes() {
    return this.get("topic.op_like_count") > 0;
  },

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
  },

  showEntrance,

  click(e) {
    const result = this.showEntrance(e);
    if (result === false) {
      return result;
    }

    const topic = this.topic;
    if (e.target.classList.contains("bulk-select")) {
      const selected = this.selected;

      if (e.target.checked) {
        selected.addObject(topic);

        if (this.lastChecked && e.shiftKey) {
          const bulkSelects = Array.from(
              document.querySelectorAll("input.bulk-select")
            ),
            from = bulkSelects.indexOf(e.target),
            to = bulkSelects.findIndex((el) => el.id === this.lastChecked.id),
            start = Math.min(from, to),
            end = Math.max(from, to);

          bulkSelects
            .slice(start, end)
            .filter((el) => el.checked !== true)
            .forEach((checkbox) => {
              checkbox.click();
            });
        }

        this.set("lastChecked", e.target);
      } else {
        selected.removeObject(topic);
        this.set("lastChecked", null);
      }
    }

    if (e.target.classList.contains("raw-topic-link")) {
      if (wantsNewWindow(e)) {
        return true;
      }
      e.preventDefault();
      return this.navigateToTopic(topic, e.target.getAttribute("href"));
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

    if (e.target.closest("a.topic-status")) {
      this.topic.togglePinnedForUser();
      return false;
    }

    return this.unhandledRowClick(e, topic);
  },

  unhandledRowClick() {},

  navigateToTopic,

  highlight(opts = { isLastViewedTopic: false }) {
    schedule("afterRender", () => {
      if (!this.element || this.isDestroying || this.isDestroyed) {
        return;
      }

      this.element.classList.add("highlighted");
      this.element.setAttribute(
        "data-islastviewedtopic",
        opts.isLastViewedTopic
      );
      this.element.addEventListener("animationend", () => {
        this.element.classList.remove("highlighted");
      });
      if (opts.isLastViewedTopic && this._shouldFocusLastVisited()) {
        this._titleElement()?.focus();
      }
    });
  },

  _highlightIfNeeded: on("didInsertElement", function () {
    // highlight the last topic viewed
    if (this.session.get("lastTopicIdViewed") === this.get("topic.id")) {
      this.session.set("lastTopicIdViewed", null);
      this.highlight({ isLastViewedTopic: true });
    } else if (this.get("topic.highlight")) {
      // highlight new topics that have been loaded from the server or the one we just created
      this.set("topic.highlight", false);
      this.highlight();
    }
  }),

  @bind
  _onTitleFocus() {
    if (this.element && !this.isDestroying && !this.isDestroyed) {
      this._mainLinkElement().classList.add("focused");
    }
  },

  @bind
  _onTitleBlur() {
    if (this.element && !this.isDestroying && !this.isDestroyed) {
      this._mainLinkElement().classList.remove("focused");
    }
  },

  _shouldFocusLastVisited() {
    return !this.site.mobileView && this.focusLastVisitedTopic;
  },

  _mainLinkElement() {
    return this.element.querySelector(".main-link");
  },

  _titleElement() {
    return this.element.querySelector(".main-link .title");
  },
});
