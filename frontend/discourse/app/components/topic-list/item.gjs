import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe, isHTMLSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import PluginOutlet from "discourse/components/plugin-outlet";
import BulkSelectCheckbox from "discourse/components/topic-list/bulk-select-checkbox";
import PostCountOrBadges from "discourse/components/topic-list/post-count-or-badges";
import TopicExcerpt from "discourse/components/topic-list/topic-excerpt";
import TopicLink from "discourse/components/topic-list/topic-link";
import TopicStatus from "discourse/components/topic-status";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import categoryLink from "discourse/helpers/category-link";
import concatClass from "discourse/helpers/concat-class";
import discourseTags from "discourse/helpers/discourse-tags";
import formatDate from "discourse/helpers/format-date";
import lazyHash from "discourse/helpers/lazy-hash";
import topicFeaturedLink from "discourse/helpers/topic-featured-link";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import {
  applyBehaviorTransformer,
  applyValueTransformer,
} from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
import { and, eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class Item extends Component {
  @service historyStore;
  @service site;
  @service siteSettings;

  highlightIfNeeded = modifier((element) => {
    if (this.args.topic.id === this.historyStore.get("lastTopicIdViewed")) {
      element.dataset.isLastViewedTopic = true;

      this.highlightRow(element);
      next(() => this.historyStore.delete("lastTopicIdViewed"));

      if (this.shouldFocusLastVisited) {
        // Using next() so it always runs after clean-dom
        next(() => element.querySelector(".main-link .title")?.focus());
      }
    } else if (this.args.topic.get("highlight")) {
      // highlight new topics that have been loaded from the server or the one we just created
      this.highlightRow(element);
      next(() => this.args.topic.set("highlight", false));
    }
  });

  get isSelected() {
    return this.args.selected?.includes(this.args.topic);
  }

  get tagClassNames() {
    return this.args.topic.tags?.map((tagName) => `tag-${tagName}`);
  }

  get expandPinned() {
    let expandPinned;
    if (
      !this.args.topic.pinned ||
      (this.useMobileLayout && !this.siteSettings.show_pinned_excerpt_mobile) ||
      (this.site.desktopView && !this.siteSettings.show_pinned_excerpt_desktop)
    ) {
      expandPinned = false;
    } else {
      expandPinned =
        (this.args.expandGloballyPinned && this.args.topic.pinned_globally) ||
        this.args.expandAllPinned;
    }

    return applyValueTransformer(
      "topic-list-item-expand-pinned",
      expandPinned,
      { topic: this.args.topic, mobileView: this.useMobileLayout }
    );
  }

  get shouldFocusLastVisited() {
    return this.site.desktopView && this.args.focusLastVisitedTopic;
  }

  @action
  navigateToTopic(topic, href) {
    this.historyStore.set("lastTopicIdViewed", topic.id);
    DiscourseURL.routeTo(href || topic.url);
  }

  highlightRow(element) {
    element.dataset.testWasHighlighted = true;

    // Remove any existing highlighted class
    element.addEventListener(
      "animationend",
      () => element.classList.remove("highlighted"),
      { once: true }
    );

    element.classList.add("highlighted");
  }

  @action
  onTitleFocus(event) {
    event.target.closest(".topic-list-item").classList.add("selected");
  }

  @action
  onTitleBlur(event) {
    event.target.closest(".topic-list-item").classList.remove("selected");
  }

  @action
  onBulkSelectToggle(e) {
    e.stopImmediatePropagation();

    const topicNode = e.target.closest(".topic-list-item");

    if (e.target.checked) {
      this.selectTopic(topicNode, e.shiftKey);
    } else {
      this.unselectTopic(topicNode);
    }
  }

  unselectTopic(topicNode) {
    removeValueFromArray(this.args.selected, this.args.topic);
    this.args.bulkSelectHelper.lastCheckedElementId = null;
    topicNode.classList.remove("bulk-selected");
  }

  selectTopic(topicNode, shiftKey) {
    addUniqueValueToArray(this.args.selected, this.args.topic);

    if (this.args.bulkSelectHelper.lastCheckedElementId && shiftKey) {
      const topics = Array.from(topicNode.parentNode.children);
      const from = topics.indexOf(topicNode);
      const to = topics.findIndex(
        (el) =>
          el.dataset.topicId === this.args.bulkSelectHelper.lastCheckedElementId
      );
      const start = Math.min(from, to);
      const end = Math.max(from, to);
      const bulkSelects = [...document.querySelectorAll("input.bulk-select")];
      bulkSelects
        .slice(start, end)
        .filter((el) => !el.checked)
        .forEach((checkbox) => checkbox.click());
    }

    this.args.bulkSelectHelper.lastCheckedElementId = topicNode.dataset.topicId;
    topicNode.classList.add("bulk-selected");
  }

  @action
  click(event) {
    if (this.args.bulkSelectEnabled) {
      event.preventDefault();

      const topicNode = event.target.closest(".topic-list-item");
      const selected = this.args.selected.includes(this.args.topic);
      if (selected) {
        this.unselectTopic(topicNode);
      } else {
        this.selectTopic(topicNode, event.shiftKey);
      }

      return;
    }

    applyBehaviorTransformer(
      "topic-list-item-click",
      () => {
        if (
          event.target.classList.contains("raw-topic-link") ||
          event.target.classList.contains("post-activity") ||
          event.target.classList.contains("badge-posts")
        ) {
          if (wantsNewWindow(event)) {
            return;
          }

          event.preventDefault();
          this.navigateToTopic(this.args.topic, event.target.href);
          return;
        }

        // make full row click target on mobile, due to size constraints
        if (
          this.site.mobileView &&
          event.target.matches(
            ".topic-list-data, .main-link, .right, .topic-item-stats, .topic-item-stats__category-tags, .discourse-tags"
          )
        ) {
          if (wantsNewWindow(event)) {
            return;
          }

          event.preventDefault();
          this.navigateToTopic(this.args.topic, this.args.topic.lastUnreadUrl);
          return;
        }
      },
      {
        event,
        topic: this.args.topic,
        navigateToTopic: this.navigateToTopic,
      }
    );
  }

  @action
  keyDown(event) {
    if (
      event.key === "Enter" &&
      (event.target.classList.contains("post-activity") ||
        event.target.classList.contains("badge-posts"))
    ) {
      event.preventDefault();
      this.navigateToTopic(this.args.topic, event.target.href);
    }
  }

  get useMobileLayout() {
    return applyValueTransformer(
      "topic-list-item-mobile-layout",
      this.site.mobileView,
      { topic: this.args.topic }
    );
  }

  get additionalClasses() {
    return applyValueTransformer("topic-list-item-class", [], {
      topic: this.args.topic,
      index: this.args.index,
    });
  }

  get style() {
    const parts = applyValueTransformer("topic-list-item-style", [], {
      topic: this.args.topic,
      index: this.args.index,
    });

    const safeParts = parts.filter(Boolean).filter((part) => {
      if (isHTMLSafe(part)) {
        return true;
      }
      // eslint-disable-next-line no-console
      console.error(
        "topic-list-item-style must be formed of htmlSafe strings. Skipped unsafe value:",
        part
      );
    });

    if (safeParts.length) {
      return htmlSafe(safeParts.join("\n"));
    }
  }

  <template>
    <tr
      {{! template-lint-disable no-invalid-interactive }}
      {{this.highlightIfNeeded}}
      {{on "keydown" this.keyDown}}
      {{on "click" this.click}}
      {{on "auxclick" this.click}}
      data-topic-id={{@topic.id}}
      role={{this.role}}
      aria-level={{this.ariaLevel}}
      class={{concatClass
        "topic-list-item"
        (if @topic.category (concat "category-" @topic.category.fullSlug))
        (if (eq @topic @lastVisitedTopic) "last-visit")
        (if @topic.visited "visited")
        (if @topic.hasExcerpt "has-excerpt")
        (if (and this.expandPinned @topic.hasExcerpt) "excerpt-expanded")
        (if @topic.unseen "unseen-topic")
        (if @topic.unread_posts "unread-posts")
        (if @topic.liked "liked")
        (if @topic.archived "archived")
        (if @topic.bookmarked "bookmarked")
        (if @topic.pinned "pinned")
        (if @topic.closed "closed")
        (if @bulkSelectEnabled "bulk-selecting")
        this.tagClassNames
        this.additionalClasses
      }}
      style={{this.style}}
    >
      <PluginOutlet
        @name="above-topic-list-item"
        @outletArgs={{lazyHash topic=@topic}}
      />
      {{! Do not include @columns as argument to the wrapper outlet below ~}}
      {{! We don't want it to be able to override core behavior just copy/pasting the code ~}}
      <PluginOutlet
        @name="topic-list-item"
        @outletArgs={{lazyHash
          topic=@topic
          bulkSelectEnabled=@bulkSelectEnabled
          onBulkSelectToggle=this.onBulkSelectToggle
          isSelected=this.isSelected
          hideCategory=@hideCategory
          tagsForUser=@tagsForUser
          showTopicPostBadges=@showTopicPostBadges
          navigateToTopic=this.navigateToTopic
        }}
      >
        {{#if this.useMobileLayout}}
          <td
            class={{concatClass
              "topic-list-data"
              (if @bulkSelectEnabled "bulk-select-enabled")
            }}
          >
            <div class="pull-left">
              {{#if @bulkSelectEnabled}}
                <BulkSelectCheckbox
                  @topic={{@topic}}
                  @isSelected={{this.isSelected}}
                  @onToggle={{this.onBulkSelectToggle}}
                />
              {{else}}
                <PluginOutlet
                  @name="topic-list-item-mobile-avatar"
                  @outletArgs={{lazyHash topic=@topic}}
                >
                  <UserLink
                    @ariaLabel={{i18n
                      "latest_poster_link"
                      username=@topic.lastPosterUser.username
                    }}
                    @username={{@topic.lastPosterUser.username}}
                  >
                    {{avatar
                      @topic.lastPosterUser
                      imageSize="large"
                    }}</UserLink>
                </PluginOutlet>
              {{/if}}
            </div>

            <div class="topic-item-metadata right">
              {{~! no whitespace ~}}
              <PluginOutlet
                @name="topic-list-before-link"
                @outletArgs={{lazyHash topic=@topic}}
              />

              <div class="main-link">
                {{~! no whitespace ~}}
                <PluginOutlet
                  @name="topic-list-before-status"
                  @outletArgs={{lazyHash topic=@topic}}
                />
                {{~! no whitespace ~}}
                <TopicStatus @topic={{@topic}} @context="topic-list" />
                {{~! no whitespace ~}}
                <TopicLink
                  {{on "focus" this.onTitleFocus}}
                  {{on "blur" this.onTitleBlur}}
                  @topic={{@topic}}
                  class="raw-link raw-topic-link"
                />
                {{~#if @topic.featured_link~}}
                  &nbsp;
                  {{~topicFeaturedLink @topic}}
                {{~/if~}}
                <PluginOutlet
                  @name="topic-list-after-title"
                  @outletArgs={{lazyHash topic=@topic}}
                />
                {{~#if @topic.unseen~}}
                  <span class="topic-post-badges">&nbsp;<span
                      class="badge-notification new-topic"
                    ></span></span>
                {{~/if~}}
                <PluginOutlet
                  @name="topic-list-after-badges"
                  @outletArgs={{lazyHash topic=@topic}}
                />
                {{~#if this.expandPinned~}}
                  <TopicExcerpt @topic={{@topic}} />
                {{~/if~}}
                <PluginOutlet
                  @name="topic-list-main-link-bottom"
                  @outletArgs={{lazyHash
                    topic=@topic
                    expandPinned=this.expandPinned
                  }}
                />
              </div>
              {{~! no whitespace ~}}
              <PluginOutlet
                @name="topic-list-after-main-link"
                @outletArgs={{lazyHash topic=@topic}}
              />

              <div class="pull-right">
                <PostCountOrBadges
                  @topic={{@topic}}
                  @postBadgesEnabled={{@showTopicPostBadges}}
                />
              </div>

              <div class="topic-item-stats clearfix">
                <span class="topic-item-stats__category-tags">
                  {{#unless @hideCategory}}
                    <PluginOutlet
                      @name="topic-list-before-category"
                      @outletArgs={{lazyHash topic=@topic}}
                    />
                    {{categoryLink @topic.category}}
                    {{~! no whitespace ~}}
                    <PluginOutlet
                      @name="topic-list-after-category"
                      @outletArgs={{lazyHash topic=@topic}}
                    />{{~! no whitespace ~}}
                  {{/unless}}
                  {{~! no whitespace ~}}
                  {{discourseTags @topic mode="list"}}
                </span>

                <div class="num activity last">
                  <PluginOutlet
                    @name="topic-list-item-mobile-bumped-at"
                    @outletArgs={{lazyHash topic=@topic}}
                  >
                    <span title={{@topic.bumpedAtTitle}} class="age activity">
                      <a href={{@topic.lastPostUrl}}>{{formatDate
                          @topic.bumpedAt
                          format="tiny"
                          noTitle="true"
                        }}</a>
                    </span>
                  </PluginOutlet>
                </div>
              </div>
            </div>
          </td>
        {{else}}
          {{#each @columns as |entry|}}
            <entry.value.item
              @topic={{@topic}}
              @bulkSelectEnabled={{@bulkSelectEnabled}}
              @onBulkSelectToggle={{this.onBulkSelectToggle}}
              @isSelected={{this.isSelected}}
              @showTopicPostBadges={{@showTopicPostBadges}}
              @hideCategory={{@hideCategory}}
              @tagsForUser={{@tagsForUser}}
              @expandPinned={{this.expandPinned}}
            />
          {{/each}}
        {{/if}}
      </PluginOutlet>
    </tr>
  </template>
}
