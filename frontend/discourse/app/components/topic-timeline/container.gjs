import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import { actionDescriptionHtml } from "discourse/components/post-action-description";
import TopicAdminMenu from "discourse/components/topic-admin-menu";
import TopicContentLanguagePreferences from "discourse/components/topic-content-language-preferences";
import UserTip from "discourse/components/user-tip";
import lazyHash from "discourse/helpers/lazy-hash";
import topicFeaturedLink from "discourse/helpers/topic-featured-link";
import { bind, debounce } from "discourse/lib/decorators";
import domUtils from "discourse/lib/dom-utils";
import { headerOffset } from "discourse/lib/offset-calculator";
import TopicNotificationsButton from "discourse/select-kit/components/topic-notifications-button";
import DButton from "discourse/ui-kit/d-button";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import BackButton from "./back-button.gjs";
import Scroller from "./scroller.gjs";

export const SCROLLER_HEIGHT = 50;
const DEFAULT_MIN_SCROLLAREA_HEIGHT = 170;
const DEFAULT_MAX_SCROLLAREA_HEIGHT = 300;
const LAST_READ_HEIGHT = 20;

let desktopMinScrollAreaHeight = DEFAULT_MIN_SCROLLAREA_HEIGHT;
let desktopMaxScrollAreaHeight = DEFAULT_MAX_SCROLLAREA_HEIGHT;

export function setDesktopScrollAreaHeight(
  height = {
    min: DEFAULT_MIN_SCROLLAREA_HEIGHT,
    max: DEFAULT_MAX_SCROLLAREA_HEIGHT,
  }
) {
  desktopMinScrollAreaHeight = height.min;
  desktopMaxScrollAreaHeight = height.max;
}

export function timelineDate(date) {
  const fmt =
    date.getFullYear() === new Date().getFullYear()
      ? "long_no_year_no_time"
      : "timeline_date";
  return moment(date).format(i18n(`dates.${fmt}`));
}

export default class TopicTimelineScrollArea extends Component {
  @service appEvents;
  @service site;
  @service siteSettings;
  @service currentUser;
  @service composer;

  @tracked current;
  @tracked percentage = this._percentFor(
    this.args.model,
    this.args.enteredIndex
  );
  @tracked total;
  @tracked date;

  /** @type {number | null} */
  @tracked lastReadPercentage = null;
  @tracked lastRead;
  @tracked before;
  @tracked after;
  @tracked timelineScrollareaStyle;
  @tracked dragging = false;
  @tracked excerpt = "";

  /** @type {IntersectionObserver | null} */
  intersectionObserver = null;

  /** @type {HTMLElement | null} */
  scrollareaElement = null;

  /** @type {HTMLElement | null} */
  scrollerElement = null;

  /** @type {number | null} */
  dragOffset = null;

  constructor() {
    super(...arguments);

    if (this.site.desktopView) {
      this.appEvents.on("topic:current-post-scrolled", this.postScrolled);
      this.appEvents.on("composer:opened", this.calculatePosition);
      this.appEvents.on("composer:resized", this.calculatePosition);
      this.appEvents.on("composer:closed", this.calculatePosition);
      this.appEvents.on("composer:preview-toggled", this.calculatePosition);
    }

    this.intersectionObserver = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        const bounds = entry.boundingClientRect;

        if (entry.target.id === "topic-bottom") {
          this.topicBottom = bounds.y + window.scrollY;
        } else {
          this.topicTop = bounds.y + window.scrollY;
        }
      }
    });

    // The timeline is usually rendered on a topic page where both of these
    // anchors exist. When it's rendered outside of that context (for example,
    // a modal opened from a floating composer on a non-topic route), they
    // may be absent — skip observing rather than crashing.
    const elements = [
      document.querySelector(".container.posts"),
      document.querySelector("#topic-bottom"),
    ].filter(Boolean);

    for (const element of elements) {
      this.intersectionObserver.observe(element);
    }

    this.calculatePosition();
    this.dockCheck();
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.intersectionObserver.disconnect();

    if (this.site.desktopView) {
      this.appEvents.off("composer:opened", this.calculatePosition);
      this.appEvents.off("composer:resized", this.calculatePosition);
      this.appEvents.off("composer:closed", this.calculatePosition);
      this.appEvents.off("composer:preview-toggled", this.calculatePosition);
      this.appEvents.off("topic:current-post-scrolled", this.postScrolled);
    }
  }

  get displaySummary() {
    return (
      this.siteSettings.summary_timeline_button &&
      !this.args.fullscreen &&
      this.args.model.has_summary &&
      !this.args.model.postStream.summary
    );
  }

  get displayTimeLineScrollArea() {
    if (this.site.mobileView) {
      return true;
    }

    if (this.total === 1) {
      const postsWrapper = document.querySelector(".posts-wrapper");
      if (postsWrapper && postsWrapper.offsetHeight < 1000) {
        return false;
      }
    }

    return true;
  }

  get canCreatePost() {
    return this.args.model.details?.can_create_post;
  }

  get showTimelineControls() {
    return (
      !this.args.fullscreen &&
      (this.currentUser || this.args.model.has_localized_content)
    );
  }

  get topicTitle() {
    return trustHTML(this.site.mobileView ? this.args.model.fancyTitle : "");
  }

  get showTags() {
    return (
      this.siteSettings.tagging_enabled && this.args.model.tags?.length > 0
    );
  }

  get beforePadding() {
    return trustHTML(`height: ${this.before}px`);
  }

  get afterPadding() {
    return trustHTML(`height: ${this.after}px`);
  }

  get hasBackPosition() {
    return (
      this.lastRead - this.current > 3 &&
      Math.abs(this.lastRead - this.total) > 1
    );
  }

  get showLastRead() {
    return (
      this.hasBackPosition &&
      (this.before + SCROLLER_HEIGHT - 5 < this.lastReadHeight ||
        this.before > this.lastReadHeight + 25)
    );
  }

  get lastReadStyle() {
    return trustHTML(
      `height: ${LAST_READ_HEIGHT}px; top: ${this.topPosition}px`
    );
  }

  get topPosition() {
    const bottom = this.scrollareaHeight - LAST_READ_HEIGHT / 2;
    return Math.min(this.lastReadHeight, bottom);
  }

  get scrollareaHeight() {
    const composerHeight = this.composer.isPreviewActive
      ? document.getElementById("reply-control")?.offsetHeight || 0
      : 0;
    const headerHeight = document.querySelector(".d-header")?.offsetHeight || 0;

    const availableHeight =
      (window.innerHeight - composerHeight - headerHeight) / 2;

    const desktopPreview =
      !this.site.mobileView && this.composer.isPreviewActive;
    const minHeight = desktopPreview
      ? desktopMinScrollAreaHeight
      : DEFAULT_MIN_SCROLLAREA_HEIGHT;
    const maxHeight = desktopPreview
      ? desktopMaxScrollAreaHeight
      : DEFAULT_MAX_SCROLLAREA_HEIGHT;

    return Math.max(minHeight, Math.min(availableHeight, maxHeight));
  }

  get startDate() {
    return timelineDate(this.args.model.createdAt);
  }

  get nowDateOptions() {
    return {
      customTitle: i18n("topic_entrance.jump_bottom_button_title"),
      addAgo: true,
      defaultFormat: timelineDate,
    };
  }

  get nowDate() {
    return (
      this.args.model.get("last_posted_at") || this.args.model.get("created_at")
    );
  }

  get lastReadHeight() {
    return Math.round(this.lastReadPercentage * this.scrollareaHeight);
  }

  @bind
  calculatePosition() {
    this.timelineScrollareaStyle = trustHTML(
      `height: ${this.scrollareaHeight}px`
    );

    const topic = this.args.model;
    const postStream = topic.postStream;
    this.total = postStream.filteredPostsCount;

    this.scrollPosition =
      this.clamp(Math.floor(this.total * this.percentage), 0, this.total) + 1;

    this.current = this.clamp(this.scrollPosition, 1, this.total);
    const daysAgo = postStream.closestDaysAgoFor(this.current);

    this.date =
      daysAgo === undefined
        ? null
        : moment().subtract(daysAgo, "days").toDate();

    const lastReadNumber = topic.last_read_post_number;
    const lastReadId = topic.last_read_post_id;

    if (lastReadId && lastReadNumber) {
      const idx = postStream.progressIndexOfPostId({
        id: lastReadId,
        post_number: lastReadNumber,
      });
      this.lastRead = idx;
      this.lastReadPercentage = this._percentFor(topic, idx);
    }

    if (this.position !== this.current) {
      this.position = this.current;
      this.updateScrollPosition(this.current);
    }

    this.before = (this.scrollareaHeight - SCROLLER_HEIGHT) * this.percentage;
    this.after = this.scrollareaHeight - this.before - SCROLLER_HEIGHT;
  }

  @debounce(50)
  updateScrollPosition(scrollPosition) {
    if (!this.args.fullscreen) {
      return;
    }

    const stream = this.args.model.postStream;

    if (this.position !== scrollPosition) {
      return;
    }

    stream.excerpt(scrollPosition - 1).then((info) => {
      if (info && this.position === scrollPosition) {
        let excerpt = "";
        if (info.username) {
          excerpt = "<span class='username'>" + info.username + ":</span> ";
        }
        if (info.excerpt) {
          this.excerpt = excerpt + info.excerpt;
        } else if (info.action_code) {
          this.excerpt = `${excerpt} ${actionDescriptionHtml(
            info.action_code,
            info.created_at,
            info.username
          )}`;
        }
      }
    });
  }

  @action
  updatePercentage(e) {
    e.preventDefault();

    const desiredScrollerCentre = e.pageY - this.dragOffset;

    const areaTop = domUtils.offset(this.scrollareaElement).top;
    const areaHeight = this.scrollareaElement.offsetHeight;
    const scrollerHeight = this.scrollerElement.offsetHeight;

    // The range of possible positions for the centre of the scroller
    const scrollableTop = areaTop + scrollerHeight / 2;
    const scrollableHeight = areaHeight - scrollerHeight;

    this.percentage = this.clamp(
      (desiredScrollerCentre - scrollableTop) / scrollableHeight
    );
    this.commit();
  }

  @bind
  didStartDrag(event) {
    const scrollerCentre =
      domUtils.offset(this.scrollerElement).top +
      this.scrollerElement.offsetHeight / 2;

    this.dragOffset = event.pageY - scrollerCentre;
    this.dragging = true;
  }

  @bind
  dragMove(event) {
    event.stopPropagation();
    event.preventDefault();
    this.updatePercentage(event);
  }

  @bind
  didEndDrag() {
    this.dragging = false;
    this.dragOffset = null;
    this.commit();
  }

  @bind
  postScrolled(e) {
    this.current = e.postIndex;
    this.percentage = e.percent;
    this.calculatePosition();
    this.dockCheck();
  }

  @action
  goBack() {
    this.args.jumpToIndex(this.lastRead);
  }

  dockCheck() {
    const timeline = document.querySelector(".timeline-container");
    const timelineHeight = timeline?.offsetHeight || 400;

    const prevDockAt = this.dockAt;
    const positionTop = headerOffset() + window.pageYOffset;
    const currentPosition = positionTop + timelineHeight;
    const postStream = this.args.model.postStream;
    const allPostsLoaded = postStream.loadedAllPosts;

    let dockBottom = false;
    if (positionTop < this.topicTop) {
      this.dockAt = parseInt(this.topicTop, 10);
    } else if (allPostsLoaded && currentPosition > this.topicBottom) {
      this.dockAt = Math.max(
        0,
        parseInt(this.topicBottom - timelineHeight, 10)
      );
      dockBottom = true;
    } else {
      this.dockAt = null;
    }

    if (this.dockAt !== prevDockAt) {
      if (this.dockAt) {
        this.args.setDocked(true);
        if (dockBottom) {
          this.args.setDockedBottom(true);
        }
      } else {
        this.args.setDocked(false);
        this.args.setDockedBottom(false);
      }
    }
  }

  commit() {
    this.calculatePosition();

    if (!this.dragging) {
      if (this.current === this.scrollPosition) {
        this.args.jumpToIndex(this.current);
      } else {
        this.args.jumpEnd();
      }
    }
  }

  clamp(p, min = 0.0, max = 1.0) {
    return Math.max(Math.min(p, max), min);
  }

  @action
  registerScrollarea(element) {
    this.scrollareaElement = element;
  }

  @action
  registerScroller(element) {
    this.scrollerElement = element;
  }

  _percentFor(topic, postIndex) {
    const total = topic.postStream.filteredPostsCount;
    switch (postIndex) {
      case 0:
        return 0;
      case total - 1:
        return 1;
      default:
        return this.clamp(postIndex / total);
    }
  }

  <template>
    {{#if @fullscreen}}
      <div class="title">
        <h2>
          <a
            class="fancy-title"
            href={{@model.firstPostUrl}}
            {{on "click" @jumpTop}}
          >{{this.topicTitle}}</a>
        </h2>

        {{#if (or this.siteSettings.topic_featured_link_enabled this.showTags)}}
          <div class="topic-header-extra">
            {{#if this.showTags}}
              <div class="list-tags">
                <PluginOutlet
                  @name="timeline-tags-wrapper"
                  @outletArgs={{lazyHash
                    topic=@model
                    tags=@model.visibleListTags
                  }}
                >
                  {{dDiscourseTags @model mode="list" tags=@model.tags}}
                </PluginOutlet>
              </div>
            {{/if}}
            {{#if this.siteSettings.topic_featured_link_enabled}}
              {{topicFeaturedLink @model}}
            {{/if}}
          </div>
        {{/if}}

        {{#if (and (not @model.isPrivateMessage) @model.category)}}
          <div class="topic-category">
            {{#if @model.category.parentCategory}}
              {{dCategoryLink @model.category.parentCategory}}
            {{/if}}
            {{dCategoryLink @model.category}}
          </div>
        {{/if}}

        {{#if this.excerpt}}
          <div class="post-excerpt">{{trustHTML this.excerpt}}</div>
        {{/if}}
      </div>
    {{/if}}

    {{#if this.showTimelineControls}}
      <div class="timeline-controls">
        <PluginOutlet
          @name="timeline-controls-before"
          @outletArgs={{lazyHash model=@model}}
        />

        <TopicAdminMenu
          @convertToPrivateMessage={{@convertToPrivateMessage}}
          @convertToPublicTopic={{@convertToPublicTopic}}
          @deleteTopic={{@deleteTopic}}
          @recoverTopic={{@recoverTopic}}
          @resetBumpDate={{@resetBumpDate}}
          @showChangeTimestamp={{@showChangeTimestamp}}
          @showFeatureTopic={{@showFeatureTopic}}
          @showTopicSlowModeUpdate={{@showTopicSlowModeUpdate}}
          @showTopicTimerModal={{@showTopicTimerModal}}
          @toggleArchived={{@toggleArchived}}
          @toggleClosed={{@toggleClosed}}
          @toggleMultiSelect={{@toggleMultiSelect}}
          @toggleVisibility={{@toggleVisibility}}
          @topic={{@model}}
        />

        {{#if @model.has_localized_content}}
          <TopicContentLanguagePreferences />
        {{/if}}
      </div>
    {{/if}}

    {{#if this.displayTimeLineScrollArea}}
      <UserTip
        @contentText={{i18n "user_tips.topic_timeline.content"}}
        @id="topic_timeline"
        @placement="left"
        @portalOutletSelector=".timeline-scrollarea-wrapper"
        @priority={{900}}
        @titleText={{i18n "user_tips.topic_timeline.title"}}
        @triggerSelector=".timeline-scrollarea"
      />

      <div class="timeline-scrollarea-wrapper">
        <div class="timeline-date-wrapper">
          <a
            class="start-date"
            href={{@model.firstPostUrl}}
            title={{i18n "topic_entrance.jump_top_button_title"}}
            {{on "click" this.updatePercentage}}
          >
            <span>
              {{this.startDate}}
            </span>
          </a>
        </div>

        <div
          class={{dConcatClass
            "timeline-scrollarea"
            (if this.dragging "--dragging")
          }}
          style={{this.timelineScrollareaStyle}}
          {{didInsert this.registerScrollarea}}
        >
          {{! eslint-disable ember/template-no-invalid-interactive }}
          <div
            class="timeline-padding"
            style={{this.beforePadding}}
            {{on "click" this.updatePercentage}}
          ></div>

          <Scroller
            @current={{this.current}}
            @date={{this.date}}
            @didEndDrag={{this.didEndDrag}}
            @didStartDrag={{this.didStartDrag}}
            @dragMove={{this.dragMove}}
            @fullscreen={{@fullscreen}}
            @total={{this.total}}
            {{didInsert this.registerScroller}}
          />

          {{! eslint-disable ember/template-no-invalid-interactive }}
          <div
            class="timeline-padding"
            style={{this.afterPadding}}
            {{on "click" this.updatePercentage}}
          ></div>

          {{#if this.showLastRead}}
            <div class="timeline-last-read" style={{this.lastReadStyle}}>
              {{dIcon "minus" class="progress"}}
              <BackButton @onGoBack={{this.goBack}} />
            </div>
          {{/if}}
        </div>

        <div class="timeline-date-wrapper">
          <a
            class="now-date"
            href={{@model.lastPostUrl}}
            {{on "click" this.updatePercentage}}
          >
            <span>
              {{dAgeWithTooltip this.nowDate this.nowDateOptions}}
            </span>
          </a>
        </div>
      </div>

      <div class="timeline-footer-controls">
        {{#if this.displaySummary}}
          <DButton
            class="show-summary btn-default btn-small"
            title={{i18n "summary.short_title"}}
            @action={{@showTopReplies}}
            @icon="layer-group"
            @label="summary.short_label"
          />
        {{/if}}

        {{#if (and this.currentUser (not @fullscreen) this.canCreatePost)}}
          <DButton
            class="btn-default create reply-to-post"
            title={{i18n "topic.reply.help"}}
            @action={{fn @replyToPost null}}
            @icon="reply"
          />
        {{/if}}

        {{#if @fullscreen}}
          <DButton
            class="timeline-open-jump-to-post-prompt-btn jump-to-post"
            title={{i18n "topic.progress.jump_prompt_long"}}
            @action={{@jumpToPostPrompt}}
            @label="topic.progress.jump_prompt"
          />
        {{/if}}

        {{#if (and this.currentUser this.site.desktopView)}}
          <TopicNotificationsButton
            @contentClass="topic-timeline-notifications-tracking-content"
            @expanded={{false}}
            @topic={{@model}}
          />
        {{/if}}

        <PluginOutlet
          @name="timeline-footer-controls-after"
          @outletArgs={{lazyHash model=@model fullscreen=@fullscreen}}
        />
      </div>
    {{/if}}
  </template>
}
