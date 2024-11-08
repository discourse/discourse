import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and, not, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicAdminMenu from "discourse/components/topic-admin-menu";
import UserTip from "discourse/components/user-tip";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import categoryLink from "discourse/helpers/category-link";
import discourseTags from "discourse/helpers/discourse-tags";
import topicFeaturedLink from "discourse/helpers/topic-featured-link";
import { headerOffset } from "discourse/lib/offset-calculator";
import { actionDescriptionHtml } from "discourse/widgets/post-small-action";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { bind, debounce } from "discourse-common/utils/decorators";
import domUtils from "discourse-common/utils/dom-utils";
import BackButton from "./back-button";
import Scroller from "./scroller";

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
  @tracked before;
  @tracked after;
  @tracked timelineScrollareaStyle;
  @tracked dragging = false;
  @tracked excerpt = "";

  intersectionObserver = null;
  scrollareaElement = null;
  scrollerElement = null;
  dragOffset = null;

  constructor() {
    super(...arguments);

    if (this.site.desktopView) {
      // listen for scrolling event to update timeline
      this.appEvents.on("topic:current-post-scrolled", this.postScrolled);
      // listen for composer sizing changes to update timeline
      this.appEvents.on("composer:opened", this.calculatePosition);
      this.appEvents.on("composer:resized", this.calculatePosition);
      this.appEvents.on("composer:closed", this.calculatePosition);
      this.appEvents.on("post-stream:posted", this.calculatePosition);
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

    const elements = [
      document.querySelector(".container.posts"),
      document.querySelector("#topic-bottom"),
    ];

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
      this.appEvents.off("topic:current-post-scrolled", this.postScrolled);
      this.appEvents.off("post-stream:posted", this.calculatePosition);
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

  get topicTitle() {
    return htmlSafe(this.site.mobileView ? this.args.model.fancyTitle : "");
  }

  get showTags() {
    return (
      this.siteSettings.tagging_enabled && this.args.model.tags?.length > 0
    );
  }

  get style() {
    return htmlSafe(`height: ${this.scrollareaHeight}px`);
  }

  get beforePadding() {
    return htmlSafe(`height: ${this.before}px`);
  }

  get afterPadding() {
    return htmlSafe(`height: ${this.after}px`);
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
    return htmlSafe(
      `height: ${LAST_READ_HEIGHT}px; top: ${this.topPosition}px`
    );
  }

  get topPosition() {
    const bottom = this.scrollareaHeight - LAST_READ_HEIGHT / 2;
    return this.lastReadTop > bottom ? bottom : this.lastReadTop;
  }

  get scrollareaHeight() {
    const composerHeight =
        document.getElementById("reply-control").offsetHeight || 0,
      headerHeight = document.querySelector(".d-header")?.offsetHeight || 0;

    // scrollarea takes up about half of the timeline's height
    const availableHeight =
      (window.innerHeight - composerHeight - headerHeight) / 2;

    const minHeight = this.site.mobileView
      ? DEFAULT_MIN_SCROLLAREA_HEIGHT
      : desktopMinScrollAreaHeight;
    const maxHeight = this.site.mobileView
      ? DEFAULT_MAX_SCROLLAREA_HEIGHT
      : desktopMaxScrollAreaHeight;

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
    this.timelineScrollareaStyle = htmlSafe(
      `height: ${this.scrollareaHeight}px`
    );

    const topic = this.args.model;
    const postStream = topic.postStream;
    this.total = postStream.filteredPostsCount;

    this.scrollPosition =
      this.clamp(Math.floor(this.total * this.percentage), 0, this.total) + 1;

    this.current = this.clamp(this.scrollPosition, 1, this.total);
    const daysAgo = postStream.closestDaysAgoFor(this.current);

    let date;
    if (daysAgo === undefined) {
      const post = postStream.posts.findBy(
        "id",
        postStream.stream[this.current]
      );

      if (post) {
        date = new Date(post.created_at);
      }
    } else if (daysAgo !== null) {
      date = new Date();
      date.setDate(date.getDate() - daysAgo || 0);
    } else {
      date = null;
    }

    this.date = date;

    const lastReadNumber = topic.last_read_post_number;
    const lastReadId = topic.last_read_post_id;

    if (lastReadId && lastReadNumber) {
      const idx = postStream.stream.indexOf(lastReadId) + 1;
      this.lastRead = idx;
      this.lastReadPercentage = this._percentFor(topic, idx);
    }

    if (this.position !== this.scrollPosition) {
      this.position = this.scrollPosition;
      this.updateScrollPosition(this.current);
    }

    this.before = this.scrollareaRemaining() * this.percentage;
    this.after = this.scrollareaHeight - this.before - SCROLLER_HEIGHT;

    if (this.percentage === null) {
      return;
    }

    if (this.hasBackPosition) {
      this.lastReadTop = Math.round(
        this.lastReadPercentage * this.scrollareaHeight
      );
      this.showButton =
        this.before + SCROLLER_HEIGHT - 5 < this.lastReadTop ||
        this.before > this.lastReadTop + 25;
    }
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
  updatePercentage(e) {
    e.preventDefault();

    const currentCursorY = e.pageY || e.touches[0].pageY;

    const desiredScrollerCentre = currentCursorY - this.dragOffset;

    const areaTop = domUtils.offset(this.scrollareaElement).top;
    const areaHeight = this.scrollareaElement.offsetHeight;
    const scrollerHeight = this.scrollerElement.offsetHeight;

    // The range of possible positions for the centre of the scroller
    const scrollableTop = areaTop + scrollerHeight / 2;
    const scrollableHeight = areaHeight - scrollerHeight;

    this.percentage = this.clamp(
      parseFloat(desiredScrollerCentre - scrollableTop) / scrollableHeight
    );
    this.commit();
  }

  @bind
  didStartDrag(event) {
    const y = event.pageY || event.touches[0].pageY;

    const scrollerCentre =
      domUtils.offset(this.scrollerElement).top +
      this.scrollerElement.offsetHeight / 2;

    this.dragOffset = y - scrollerCentre;
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
    const timelineHeight = (timeline && timeline.offsetHeight) || 400;

    const prevDockAt = this.dockAt;
    const positionTop = headerOffset() + window.pageYOffset;
    const currentPosition = positionTop + timelineHeight;

    this.dockBottom = false;
    if (positionTop < this.topicTop) {
      this.dockAt = parseInt(this.topicTop, 10);
    } else if (currentPosition > this.topicBottom) {
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

  scrollareaRemaining() {
    return this.scrollareaHeight - SCROLLER_HEIGHT;
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
  registerScrollarea(element) {
    this.scrollareaElement = element;
  }

  @action
  registerScroller(element) {
    this.scrollerElement = element;
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
                {{discourseTags @model mode="list" tags=@model.tags}}
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
              {{categoryLink @model.category.parentCategory}}
            {{/if}}
            {{categoryLink @model.category}}
          </div>
        {{/if}}

        {{#if this.excerpt}}
          <div class="post-excerpt">{{htmlSafe this.excerpt}}</div>
        {{/if}}
      </div>
    {{/if}}

    {{#if (and (not @fullscreen) this.currentUser)}}
      <div class="timeline-controls">
        <PluginOutlet
          @name="timeline-controls-before"
          @outletArgs={{hash model=@model}}
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
      </div>
    {{/if}}

    {{#if this.displayTimeLineScrollArea}}
      <UserTip
        @id="topic_timeline"
        @titleText={{i18n "user_tips.topic_timeline.title"}}
        @contentText={{i18n "user_tips.topic_timeline.content"}}
        @placement="left"
        @triggerSelector=".timeline-scrollarea-wrapper"
        @priority={{900}}
      />

      <div class="timeline-scrollarea-wrapper">
        <div class="timeline-date-wrapper">
          <a
            {{on "click" this.updatePercentage}}
            href={{@model.firstPostUrl}}
            title={{i18n "topic_entrance.jump_top_button_title"}}
            class="start-date"
          >
            <span>
              {{this.startDate}}
            </span>
          </a>
        </div>

        <div
          class="timeline-scrollarea"
          style={{this.timelineScrollareaStyle}}
          {{didInsert this.registerScrollarea}}
        >
          <div
            {{! template-lint-disable no-invalid-interactive }}
            {{on "click" this.updatePercentage}}
            style={{this.beforePadding}}
            class="timeline-padding"
          ></div>

          <Scroller
            @current={{this.current}}
            @total={{this.total}}
            @onGoBack={{this.onGoBack}}
            @fullscreen={{@fullscreen}}
            @showDockedButton={{this.showDockedButton}}
            @date={{this.date}}
            @didStartDrag={{this.didStartDrag}}
            @dragMove={{this.dragMove}}
            @didEndDrag={{this.didEndDrag}}
            {{didInsert this.registerScroller}}
          />

          <div
            {{! template-lint-disable no-invalid-interactive }}
            {{on "click" this.updatePercentage}}
            style={{this.afterPadding}}
            class="timeline-padding"
          ></div>

          {{#if (and this.hasBackPosition this.showButton)}}
            <div class="timeline-last-read" style={{this.lastReadStyle}}>
              {{icon "minus" class="progress"}}
              <BackButton @onGoBack={{this.goBack}} />
            </div>
          {{/if}}
        </div>

        <div class="timeline-date-wrapper">
          <a
            {{on "click" this.updatePercentage}}
            href={{@model.lastPostUrl}}
            class="now-date"
          >
            <span>
              {{ageWithTooltip this.nowDate this.nowDateOptions}}
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
            class="show-summary btn-small"
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

        <PluginOutlet
          @name="timeline-footer-controls-after"
          @outletArgs={{hash model=@model fullscreen=@fullscreen}}
        />
      </div>
    {{/if}}
  </template>
}
