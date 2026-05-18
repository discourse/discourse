import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import { actionDescriptionHtml } from "discourse/components/post-action-description";
import TimelineScrubber, {
  SCROLLER_HEIGHT,
} from "discourse/components/timeline-scrubber";
import TopicAdminMenu from "discourse/components/topic-admin-menu";
import TopicLocalizedContentToggle from "discourse/components/topic-localized-content-toggle";
import UserTip from "discourse/components/user-tip";
import lazyHash from "discourse/helpers/lazy-hash";
import topicFeaturedLink from "discourse/helpers/topic-featured-link";
import { bind, debounce } from "discourse/lib/decorators";
import { headerOffset } from "discourse/lib/offset-calculator";
import TopicNotificationsButton from "discourse/select-kit/components/topic-notifications-button";
import { and, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import BackButton from "./back-button";

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

  @tracked showButton = false;
  @tracked current;
  @tracked percentage = this._percentFor(
    this.args.model,
    this.args.enteredIndex
  );
  @tracked total;
  @tracked date;
  @tracked lastReadPercentage = null;
  @tracked lastRead;
  @tracked lastReadTop;
  @tracked excerpt = "";

  intersectionObserver = null;

  constructor() {
    super(...arguments);

    if (this.site.desktopView) {
      // listen for scrolling event to update timeline
      this.appEvents.on("topic:current-post-scrolled", this.postScrolled);
      // listen for composer sizing changes to update timeline
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

    for (let i = 0; i < elements.length; i++) {
      this.intersectionObserver.observe(elements[i]);
    }

    this.calculatePosition();
    this.dockCheck();
  }

  willDestroy() {
    super.willDestroy(...arguments);

    if (this.site.desktopView) {
      this.intersectionObserver?.disconnect();
      this.intersectionObserver = null;

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
      !this.args.fullScreen &&
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

  get showDockedButton() {
    return this.site.desktopView && this.hasBackPosition && !this.showButton;
  }

  get hasBackPosition() {
    return (
      this.lastRead &&
      this.lastRead > 3 &&
      this.lastRead > this.current &&
      Math.abs(this.lastRead - this.current) > 3 &&
      Math.abs(this.lastRead - this.total) > 1 &&
      this.lastRead !== this.total
    );
  }

  get lastReadStyle() {
    return trustHTML(
      `height: ${LAST_READ_HEIGHT}px; top: ${this.topPosition}px`
    );
  }

  get topPosition() {
    const bottom = this.scrollareaHeight - LAST_READ_HEIGHT / 2;
    return this.lastReadTop > bottom ? bottom : this.lastReadTop;
  }

  get scrollareaHeight() {
    const composerHeight = this.composer.isPreviewVisible
        ? document.getElementById("reply-control").offsetHeight || 0
        : 0,
      headerHeight = document.querySelector(".d-header")?.offsetHeight || 0;

    // scrollarea takes up about half of the timeline's height
    const availableHeight =
      (window.innerHeight - composerHeight - headerHeight) / 2;

    const minHeight = this.site.mobileView
      ? DEFAULT_MIN_SCROLLAREA_HEIGHT
      : this.composer.isPreviewVisible
        ? desktopMinScrollAreaHeight
        : DEFAULT_MIN_SCROLLAREA_HEIGHT;
    const maxHeight = this.site.mobileView
      ? DEFAULT_MAX_SCROLLAREA_HEIGHT
      : this.composer.isPreviewVisible
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

  get keyboardStep() {
    return this.total ? 1 / this.total : 0.05;
  }

  get lastReadHeight() {
    return Math.round(this.lastReadPercentage * this.scrollareaHeight);
  }

  @bind
  calculatePosition() {
    const topic = this.args.model;
    const postStream = topic.postStream;
    this.total = postStream.filteredPostsCount;

    this.scrollPosition =
      this.clamp(Math.floor(this.total * this.percentage), 0, this.total) + 1;

    this.current = this.clamp(this.scrollPosition, 1, this.total);
    this.date = this.#dateForPostIndex(this.current);

    const lastReadId = topic.last_read_post_id;
    if (lastReadId && topic.last_read_post_number) {
      const idx = postStream.stream.indexOf(lastReadId) + 1;
      this.lastRead = idx;
      this.lastReadPercentage = this._percentFor(topic, idx);
    }

    if (this.position !== this.scrollPosition) {
      this.position = this.scrollPosition;
      this.updateScrollPosition(this.current);
    }

    if (this.percentage === null) {
      return;
    }

    if (this.hasBackPosition) {
      this.lastReadTop = Math.round(
        this.lastReadPercentage * this.scrollareaHeight
      );
      const scrollerTop =
        this.percentage * (this.scrollareaHeight - SCROLLER_HEIGHT);
      this.showButton =
        scrollerTop + SCROLLER_HEIGHT - 5 < this.lastReadTop ||
        scrollerTop > this.lastReadTop + 25;
    }
  }

  #dateForPostIndex(index) {
    const postStream = this.args.model.postStream;
    const daysAgo = postStream.closestDaysAgoFor(index);
    if (daysAgo === undefined) {
      const post = postStream.posts.find(
        (p) => p.id === postStream.stream[index]
      );
      return post ? new Date(post.created_at) : null;
    }
    if (daysAgo !== null) {
      const date = new Date();
      date.setDate(date.getDate() - daysAgo || 0);
      return date;
    }
    return null;
  }

  @debounce(50)
  updateScrollPosition(scrollPosition) {
    // only ran on mobile
    if (!this.args.fullscreen) {
      return;
    }

    const stream = this.args.model.postStream;

    if (!this.position === scrollPosition) {
      return;
    }

    // we have an off by one, stream is zero based,
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
  handleCommit(progress) {
    this.percentage = this.clamp(progress);
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
    const timelineHeight = (timeline && timeline.offsetHeight) || 400;

    const prevDockAt = this.dockAt;
    const positionTop = headerOffset() + window.pageYOffset;
    const currentPosition = positionTop + timelineHeight;
    const postStream = this.args.model.postStream;
    const allPostsLoaded = postStream.loadedAllPosts;

    this.dockBottom = false;
    if (positionTop < this.topicTop) {
      this.dockAt = parseInt(this.topicTop, 10);
    } else if (allPostsLoaded && currentPosition > this.topicBottom) {
      this.dockAt = parseInt(this.topicBottom - timelineHeight, 10);
      this.dockBottom = true;
      if (this.dockAt < 0) {
        this.dockAt = 0;
      }
    } else {
      this.dockAt = null;
    }

    if (this.dockAt !== prevDockAt) {
      if (this.dockAt) {
        this.args.setDocked(true);
        if (this.dockBottom) {
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

    if (this.current === this.scrollPosition) {
      this.args.jumpToIndex(this.current);
    } else {
      this.args.jumpEnd();
    }
  }

  clamp(p, min = 0.0, max = 1.0) {
    return Math.max(Math.min(p, max), min);
  }

  _percentFor(topic, postIndex) {
    const total = topic.postStream.filteredPostsCount;
    switch (postIndex) {
      // if first post, no top padding
      case 0:
        return 0;
      // if last, no bottom padding
      case total - 1:
        return 1;
      // otherwise, calculate
      default:
        return this.clamp(parseFloat(postIndex) / total);
    }
  }

  @action
  currentAt(progress) {
    const total = this.total;
    if (!total) {
      return 1;
    }
    const pos = this.clamp(Math.floor(total * progress), 0, total) + 1;
    return this.clamp(pos, 1, total);
  }

  @action
  dateAt(progress) {
    return this.#dateForPostIndex(this.currentAt(progress));
  }

  @action
  formatTimelineDate(date) {
    return timelineDate(date);
  }

  <template>
    {{#if @fullscreen}}
      <div class="title">
        <h2>
          <a
            {{on "click" @jumpTop}}
            href={{@model.firstPostUrl}}
            class="fancy-title"
          >{{this.topicTitle}}</a>
        </h2>

        {{#if (or this.siteSettings.topic_featured_link_enabled this.showTags)}}
          <div class="topic-header-extra">
            {{#if this.showTags}}
              <div class="list-tags">
                {{dDiscourseTags @model mode="list" tags=@model.tags}}
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
          @topic={{@model}}
          @toggleMultiSelect={{@toggleMultiSelect}}
          @showTopicSlowModeUpdate={{@showTopicSlowModeUpdate}}
          @deleteTopic={{@deleteTopic}}
          @recoverTopic={{@recoverTopic}}
          @toggleClosed={{@toggleClosed}}
          @toggleArchived={{@toggleArchived}}
          @toggleVisibility={{@toggleVisibility}}
          @showTopicTimerModal={{@showTopicTimerModal}}
          @showFeatureTopic={{@showFeatureTopic}}
          @showChangeTimestamp={{@showChangeTimestamp}}
          @resetBumpDate={{@resetBumpDate}}
          @convertToPublicTopic={{@convertToPublicTopic}}
          @convertToPrivateMessage={{@convertToPrivateMessage}}
        />

        {{#if @model.has_localized_content}}
          <TopicLocalizedContentToggle @topic={{@model}} />
        {{/if}}
      </div>
    {{/if}}

    {{#if this.displayTimeLineScrollArea}}
      <UserTip
        @id="topic_timeline"
        @titleText={{i18n "user_tips.topic_timeline.title"}}
        @contentText={{i18n "user_tips.topic_timeline.content"}}
        @placement="left"
        @portalOutletSelector=".timeline-scrollarea-wrapper"
        @triggerSelector=".timeline-scrollarea"
        @priority={{900}}
      />

      <div class="timeline-scrollarea-wrapper">
        <div class="timeline-date-wrapper">
          <a
            href={{@model.firstPostUrl}}
            title={{i18n "topic_entrance.jump_top_button_title"}}
            class="start-date"
            {{on "click" @jumpTop}}
          >
            <span>
              {{this.startDate}}
            </span>
          </a>
        </div>

        <TimelineScrubber
          class="topic-timeline-scrubber"
          @progress={{this.percentage}}
          @height={{this.scrollareaHeight}}
          @ariaLabel={{i18n "topic.progress.title"}}
          @ariaValueText={{i18n
            "topic.timeline.replies_short"
            current=this.current
            total=this.total
          }}
          @keyboardStep={{this.keyboardStep}}
          @onCommit={{this.handleCommit}}
        >
          <:track>
            {{#if (and this.hasBackPosition this.showButton)}}
              <div class="timeline-last-read" style={{this.lastReadStyle}}>
                {{dIcon "minus" class="progress"}}
                <BackButton @onGoBack={{this.goBack}} />
              </div>
            {{/if}}
          </:track>
          <:handle as |progress dragging|>
            <div class="timeline-replies">
              {{i18n
                "topic.timeline.replies_short"
                current=(this.currentAt progress)
                total=this.total
              }}
            </div>
            {{#let (this.dateAt progress) as |scrubDate|}}
              {{#if scrubDate}}
                <div class="timeline-ago">
                  {{this.formatTimelineDate scrubDate}}
                </div>
              {{/if}}
            {{/let}}
            {{! Hide while dragging so it doesn't fight the moving handle. }}
            {{#if (and this.showDockedButton (not dragging))}}
              <BackButton @onGoBack={{this.goBack}} />
            {{/if}}
          </:handle>
        </TimelineScrubber>

        <div class="timeline-date-wrapper">
          <a
            href={{@model.lastPostUrl}}
            class="now-date"
            {{on "click" @jumpBottom}}
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
            @action={{@showTopReplies}}
            @icon="layer-group"
            @label="summary.short_label"
            title={{i18n "summary.short_title"}}
            class="show-summary btn-default btn-small"
          />
        {{/if}}

        {{#if (and this.currentUser (not @fullscreen))}}
          {{#if this.canCreatePost}}
            <DButton
              @action={{fn @replyToPost null}}
              @icon="reply"
              title={{i18n "topic.reply.help"}}
              class="btn-default create reply-to-post"
            />
          {{/if}}
        {{/if}}

        {{#if @fullscreen}}
          <DButton
            @action={{@jumpToPostPrompt}}
            @label="topic.progress.jump_prompt"
            title={{i18n "topic.progress.jump_prompt_long"}}
            class="timeline-open-jump-to-post-prompt-btn jump-to-post"
          />
        {{/if}}

        {{#if (and this.currentUser this.site.desktopView)}}
          <TopicNotificationsButton
            @contentClass="topic-timeline-notifications-tracking-content"
            @topic={{@model}}
            @expanded={{false}}
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
