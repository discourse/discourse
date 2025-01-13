import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { eq } from "truth-helpers";
import PluginOutlet from "discourse/components/plugin-outlet";
import PostCountOrBadges from "discourse/components/topic-list/post-count-or-badges";
import TopicExcerpt from "discourse/components/topic-list/topic-excerpt";
import TopicLink from "discourse/components/topic-list/topic-link";
import TopicStatus from "discourse/components/topic-status";
import avatar from "discourse/helpers/avatar";
import categoryLink from "discourse/helpers/category-link";
import concatClass from "discourse/helpers/concat-class";
import discourseTags from "discourse/helpers/discourse-tags";
import formatDate from "discourse/helpers/format-date";
import topicFeaturedLink from "discourse/helpers/topic-featured-link";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { applyValueTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
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
      (this.site.mobileView && !this.siteSettings.show_pinned_excerpt_mobile) ||
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
      { topic: this.args.topic, mobileView: this.site.mobileView }
    );
  }

  get shouldFocusLastVisited() {
    return this.site.desktopView && this.args.focusLastVisitedTopic;
  }

  navigateToTopic(topic, href) {
    this.historyStore.set("lastTopicIdViewed", topic.id);
    DiscourseURL.routeTo(href || topic.url);
  }

  highlightRow(element) {
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
    if (e.target.checked) {
      this.args.selected.addObject(this.args.topic);

      if (this.args.bulkSelectHelper.lastCheckedElementId && e.shiftKey) {
        const bulkSelects = [...document.querySelectorAll("input.bulk-select")];
        const from = bulkSelects.indexOf(e.target);
        const to = bulkSelects.findIndex(
          (el) => el.id === this.args.bulkSelectHelper.lastCheckedElementId
        );
        const start = Math.min(from, to);
        const end = Math.max(from, to);

        bulkSelects
          .slice(start, end)
          .filter((el) => !el.checked)
          .forEach((checkbox) => checkbox.click());
      }

      this.args.bulkSelectHelper.lastCheckedElementId = e.target.id;
    } else {
      this.args.selected.removeObject(this.args.topic);
      this.args.bulkSelectHelper.lastCheckedElementId = null;
    }
  }

  @action
  click(e) {
    if (
      e.target.classList.contains("raw-topic-link") ||
      e.target.classList.contains("post-activity") ||
      e.target.classList.contains("badge-posts")
    ) {
      if (wantsNewWindow(e)) {
        return;
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
        return;
      }

      e.preventDefault();
      this.navigateToTopic(this.args.topic, this.args.topic.lastUnreadUrl);
      return;
    }
  }

  @action
  keyDown(e) {
    if (
      e.key === "Enter" &&
      (e.target.classList.contains("post-activity") ||
        e.target.classList.contains("badge-posts"))
    ) {
      e.preventDefault();
      this.navigateToTopic(this.args.topic, e.target.href);
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

  <template>
    <tr
      {{! template-lint-disable no-invalid-interactive }}
      {{this.highlightIfNeeded}}
      {{on "keydown" this.keyDown}}
      {{on "click" this.click}}
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
        this.additionalClasses
      }}
    >
      <PluginOutlet
        @name="above-topic-list-item"
        @outletArgs={{hash topic=@topic}}
      />
      {{#if this.useMobileLayout}}
        <td class="topic-list-data">
          <PluginOutlet
            @name="topic-list-data-mobile"
            @outletArgs={{hash
              topic=@topic
              bulkSelectEnabled=@bulkSelectEnabled
              onBulkSelectToggle=this.onBulkSelectToggle
              isSelected=this.isSelected
              showTopicPostBadges=@showTopicPostBadges
              hideCategory=@hideCategory
              tagsForUser=@tagsForUser
              expandPinned=this.expandPinned
              useMobileLayout=this.useMobileLayout
            }}
          >
            <div class="pull-left">
              {{#if @bulkSelectEnabled}}
                <label for="bulk-select-{{@topic.id}}">
                  <input
                    {{on "click" this.onBulkSelectToggle}}
                    checked={{this.isSelected}}
                    type="checkbox"
                    id="bulk-select-{{@topic.id}}"
                    class="bulk-select"
                  />
                </label>
              {{else}}
                <a
                  href={{@topic.lastPostUrl}}
                  aria-label={{i18n
                    "latest_poster_link"
                    username=@topic.lastPosterUser.username
                  }}
                  data-user-card={{@topic.lastPosterUser.username}}
                >{{avatar @topic.lastPosterUser imageSize="large"}}</a>
              {{/if}}
            </div>

            <div class="topic-item-metadata right">
              {{~! no whitespace ~}}
              <PluginOutlet
                @name="topic-list-before-link"
                @outletArgs={{hash topic=@topic}}
              />

              <div class="main-link">
                {{~! no whitespace ~}}
                <PluginOutlet
                  @name="topic-list-before-status"
                  @outletArgs={{hash topic=@topic}}
                />
                {{~! no whitespace ~}}
                <TopicStatus @topic={{@topic}} />
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
                  @outletArgs={{hash topic=@topic}}
                />
                {{~#if @topic.unseen~}}
                  <span class="topic-post-badges">&nbsp;<span
                      class="badge-notification new-topic"
                    ></span></span>
                {{~/if~}}
                {{~#if this.expandPinned~}}
                  <TopicExcerpt @topic={{@topic}} />
                {{~/if~}}
                <PluginOutlet
                  @name="topic-list-main-link-bottom"
                  @outletArgs={{hash topic=@topic}}
                />
              </div>
              {{~! no whitespace ~}}
              <PluginOutlet
                @name="topic-list-after-main-link"
                @outletArgs={{hash topic=@topic}}
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
                      @outletArgs={{hash topic=@topic}}
                    />
                    {{categoryLink @topic.category}}
                  {{/unless}}

                  {{discourseTags @topic mode="list"}}
                </span>

                <div class="num activity last">
                  <span title={{@topic.bumpedAtTitle}} class="age activity">
                    <a href={{@topic.lastPostUrl}}>{{formatDate
                        @topic.bumpedAt
                        format="tiny"
                        noTitle="true"
                      }}</a>
                  </span>
                </div>
              </div>
            </div>
          </PluginOutlet>
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
    </tr>
  </template>
}
