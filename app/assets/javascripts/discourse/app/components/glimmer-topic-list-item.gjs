import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import $ from "jquery";
import { eq, gt } from "truth-helpers";
import GlimmerActionList from "discourse/components/glimmer-action-list";
import GlimmerActivityColumn from "discourse/components/glimmer-activity-column";
import GlimmerParticipantGroups from "discourse/components/glimmer-participant-groups";
import GlimmerPostersColumn from "discourse/components/glimmer-posters-column";
import GlimmerPostsCountColumn from "discourse/components/glimmer-posts-count-column";
import GlimmerTopicExcerpt from "discourse/components/glimmer-topic-excerpt";
import GlimmerUnreadIndicator from "discourse/components/glimmer-unread-indicator";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicLink from "discourse/components/topic-link";
import TopicPostBadges from "discourse/components/topic-post-badges";
import TopicStatus from "discourse/components/topic-status";
import { topicTitleDecorators } from "discourse/components/topic-title";
import categoryLink from "discourse/helpers/category-link";
import concatClass from "discourse/helpers/concat-class";
import discourseTags from "discourse/helpers/discourse-tags";
import number from "discourse/helpers/number";
import topicFeaturedLink from "discourse/helpers/topic-featured-link";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import DiscourseURL, { groupPath } from "discourse/lib/url";
import icon from "discourse-common/helpers/d-icon";
import { bind, observes } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default class GlimmerTopicListItem extends Component {
  @service currentUser;
  @service historyStore;
  @service messageBus;
  @service router;
  @service site;
  @service siteSettings;

  constructor() {
    super(...arguments);
    //   this.highlightIfNeeded();

    if (this.includeUnreadIndicator) {
      this.messageBus.subscribe(this.unreadIndicatorChannel, this.onMessage);
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.messageBus.unsubscribe(this.unreadIndicatorChannel, this.onMessage);

    // if (this.shouldFocusLastVisited) {
    //   const title = this.titleElement;
    //   if (title) {
    //     title.removeEventListener("focus", this.onTitleFocus);
    //     title.removeEventListener("blur", this.onTitleBlur);
    //   }
    // }
  }

  // Ideally this should be a modifier... but we can't do that
  // until this component has its tagName removed.
  highlightIfNeeded() {
    const lastViewedTopicId = this.historyStore.get("lastTopicIdViewed");

    if (lastViewedTopicId === this.args.topic.id) {
      this.historyStore.delete("lastTopicIdViewed");
      this.highlight({ isLastViewedTopic: true });
    } else if (this.args.topic.highlight) {
      // highlight new topics that have been loaded from the server or the one we just created
      this.set("topic.highlight", false);
      this.highlight();
    }
  }

  // Already-rendered topic is marked as highlighted
  @observes("topic.highlight")
  topicHighlightChanged() {
    if (this.args.topic.highlight) {
      this.highlightIfNeeded();
    }
  }

  get isSelected() {
    return this.args.selected?.includes(this.args.topic);
  }

  showEntrance(e) {
    let target = $(e.target);

    if (
      target.hasClass("posts-map") ||
      target.parents(".posts-map").length > 0
    ) {
      if (target.prop("tagName") !== "A") {
        target = target.find("a");
        if (target.length === 0) {
          target = target.end();
        }
      }

      this.appEvents.trigger("topic-entrance:show", {
        topic: this.args.topic,
        position: target.offset(),
      });
      return false;
    }
  }

  navigateToTopic(topic, href) {
    this.historyStore.set("lastTopicIdViewed", topic.id);
    DiscourseURL.routeTo(href || topic.url);
  }

  @bind
  onMessage(data) {
    const nodeClassList = document.querySelector(
      `.indicator-topic-${data.topic_id}`
    ).classList;

    nodeClassList.toggle("read", !data.show_indicator);
  }

  get participantGroups() {
    if (!this.args.topic.participant_groups) {
      return [];
    }

    return this.args.topic.participant_groups.map((name) => ({
      name,
      url: groupPath(name),
    }));
  }

  get unreadIndicatorChannel() {
    return `/private-messages/unread-indicator/${this.args.topic.id}`;
  }

  get unreadClass() {
    return this.args.topic.unread_by_group_member ? "" : "read";
  }

  get includeUnreadIndicator() {
    return typeof this.args.topic.unread_by_group_member !== "undefined";
  }

  get newDotText() {
    return this.currentUser?.trust_level > 0
      ? ""
      : I18n.t("filters.new.lower_title");
  }

  get tagClassNames() {
    return this.args.topic.tags?.map((tagName) => `tag-${tagName}`);
  }

  get expandPinned() {
    if (
      !this.args.topic.pinned ||
      (this.site.mobileView && !this.siteSettings.show_pinned_excerpt_mobile) ||
      (this.site.desktopView && !this.siteSettings.show_pinned_excerpt_desktop)
    ) {
      return false;
    }

    return (
      (this.args.expandGloballyPinned && this.args.topic.pinned_globally) ||
      this.args.expandAllPinned
    );
  }

  @action
  applyTitleDecorators(element) {
    const rawTopicLink = element.querySelector(".raw-topic-link");

    if (rawTopicLink) {
      topicTitleDecorators?.forEach((cb) =>
        cb(this.args.topic, rawTopicLink, "topic-list-item-title")
      );
    }
  }

  @action
  onBulkSelectToggle(e) {
    if (e.target.checked) {
      this.args.selected.addObject(this.args.topic);

      if (this.args.lastCheckedElementId && e.shiftKey) {
        const bulkSelects = Array.from(
          document.querySelectorAll("input.bulk-select")
        );
        const from = bulkSelects.indexOf(e.target);
        const to = bulkSelects.findIndex(
          (el) => el.id === this.args.lastCheckedElementId
        );
        const start = Math.min(from, to);
        const end = Math.max(from, to);

        bulkSelects
          .slice(start, end)
          .filter((el) => !el.checked)
          .forEach((checkbox) => checkbox.click());
      }

      this.args.updateLastCheckedElementId(e.target.id);
    } else {
      this.selected.removeObject(this.args.topic);
      this.updateLastCheckedElementId(null);
    }
  }

  click(e) {
    const result = this.showEntrance(e);
    if (result === false) {
      return result;
    }

    if (
      e.target.classList.contains("raw-topic-link") ||
      e.target.classList.contains("post-activity")
    ) {
      if (wantsNewWindow(e)) {
        return true;
      }

      e.preventDefault();
      this.navigateToTopic(this.args.topic, e.target.href);
      return;
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
      this.navigateToTopic(this.args.topic, this.args.topic.lastUnreadUrl);
      return;
    }

    if (
      e.target.classList.contains("d-icon-thumbtack") &&
      e.target.closest("a.topic-status")
    ) {
      e.preventDefault();
      this.args.topic.togglePinnedForUser();
      return;
    }

    return this.unhandledRowClick(e, this.args.topic);
  }

  // TODO: Doesn't work
  @action
  keyDown(e) {
    if (e.key === "Enter" && e.target.classList.contains("post-activity")) {
      e.preventDefault();
      this.navigateToTopic(this.args.topic, e.target.getAttribute("href"));
    }
  }

  highlight(opts = { isLastViewedTopic: false }) {
    schedule("afterRender", () => {
      if (this.isDestroying || this.isDestroyed) {
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

      if (opts.isLastViewedTopic && this.shouldFocusLastVisited) {
        this.titleElement?.focus();
      }
    });
  }

  @bind
  onTitleFocus() {
    if (!this.isDestroying && !this.isDestroyed) {
      this.element.classList.add("selected");
    }
  }

  @bind
  onTitleBlur() {
    if (!this.isDestroying && !this.isDestroyed) {
      this.element.classList.remove("selected");
    }
  }

  get shouldFocusLastVisited() {
    return this.site.desktopView && this.args.focusLastVisitedTopic;
  }

  get titleElement() {
    return this.element.querySelector(".main-link .title");
  }

  <template>
    <tr
      {{didInsert this.applyTitleDecorators}}
      {{on "keydown" this.keyDown}}
      data-topic-id={{@topic.id}}
      role={{this.role}}
      aria-level={{this.ariaLevel}}
      class={{concatClass
        "topic-list-item"
        (if @topic.category (concat "category-" @topic.category.fullSlug))
        (if (eq @topic @lastVisitedTopic) "last-visit")
        (if @topic.visited "visited")
        (if @topic.hasExcerpt "has-excerpt")
        (if @topic.unseen "unseen-topic")
        (if @topic.unread_posts "unread-posts")
        (if @topic.liked "liked")
        (if @topic.archived "archived")
        (if @topic.bookmarked "bookmarked")
        (if @topic.pinned "pinned")
        (if @topic.closed "closed")
        this.tagClassNames
      }}
    >
      <PluginOutlet
        @name="above-topic-list-item"
        @outletArgs={{hash topic=@topic}}
      />
      {{! TODO: convert topic-list-before-columns outlets into above-topic-list-item }}

      {{#if @bulkSelectEnabled}}
        <td class="bulk-select topic-list-data">
          <label for="bulk-select-{{@topic.id}}">
            <input
              {{on "click" this.onBulkSelectToggle}}
              checked={{this.isSelected}}
              type="checkbox"
              id="bulk-select-{{@topic.id}}"
              class="bulk-select"
            />
          </label>
        </td>
      {{/if}}

      <td class="main-link clearfix topic-list-data" colspan="1">
        <PluginOutlet @name="topic-list-before-link" />

        <span
          class="link-top-line"
        >{{!
          no whitespace
          }}<PluginOutlet
            @name="topic-list-before-status"
          />{{!
          no whitespace
          }}<TopicStatus
            @topic={{@topic}}
          />{{!
          no whitespace
          }}<TopicLink
            @topic={{@topic}}
            class="raw-link raw-topic-link"
          />
          {{~#if @topic.featured_link~}}
            &nbsp;
            {{~topicFeaturedLink @topic}}
          {{~/if~}}
          <PluginOutlet
            @name="topic-list-after-title"
          />{{!
          no whitespace
          }}
          <GlimmerUnreadIndicator
            @includeUnreadIndicator={{this.includeUnreadIndicator}}
            @topicId={{@topic.id}}
            class={{this.unreadClass}}
          />
          {{~#if @showTopicPostBadges~}}
            <TopicPostBadges
              @unreadPosts={{@topic.unread_posts}}
              @unseen={{@topic.unseen}}
              @newDotText={{this.newDotText}}
              @url={{@topic.lastUnreadUrl}}
            />
          {{~/if~}}
        </span>

        <div class="link-bottom-line">
          {{#unless @hideCategory}}
            {{#unless @topic.isPinnedUncategorized}}
              <PluginOutlet @name="topic-list-before-category" />
              {{categoryLink @topic.category}}
            {{/unless}}
          {{/unless}}

          {{discourseTags @topic mode="list" tagsForUser=@tagsForUser}}

          {{#if this.participantGroups}}
            <GlimmerParticipantGroups @groups={{this.participantGroups}} />
          {{/if}}

          <GlimmerActionList
            @topic={{@topic}}
            @postNumbers={{@topic.liked_post_numbers}}
            @icon="heart"
            class="likes"
          />
        </div>

        {{#if this.expandPinned}}
          <GlimmerTopicExcerpt @topic={{@topic}} />
        {{/if}}

        <PluginOutlet @name="topic-list-main-link-bottom" />
      </td>

      <PluginOutlet @name="topic-list-after-main-link" />

      {{#if @showPosters}}
        <GlimmerPostersColumn @posters={{@topic.featuredUsers}} />
      {{/if}}

      <GlimmerPostsCountColumn @topic={{@topic}} />

      {{#if @showLikes}}
        <td class="num likes topic-list-data">
          {{#if (gt @topic.like_count 0)}}
            <a href="{{@topic.summaryUrl}}">
              {{number @topic.like_count}}
              {{icon "heart"}}
            </a>
          {{/if}}
        </td>
      {{/if}}

      {{#if @showOpLikes}}
        <td class="num likes">
          {{#if (gt @topic.op_like_count 0)}}
            <a href={{@topic.summaryUrl}}>
              {{number @topic.op_like_count}}
              {{icon "heart"}}
            </a>
          {{/if}}
        </td>
      {{/if}}

      <td class="num views {{@topic.viewsHeat}} topic-list-data">
        <PluginOutlet @name="topic-list-before-view-count" />
        {{number @topic.views numberKey="views_long"}}
      </td>

      <GlimmerActivityColumn @topic={{@topic}} class="num topic-list-data" />

      <PluginOutlet @name="topic-list-after-columns" />
    </tr>
  </template>
}
