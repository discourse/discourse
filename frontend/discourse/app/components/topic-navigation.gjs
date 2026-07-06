import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import {
  isDestroyed,
  isDestroying,
  registerDestructor,
} from "@ember/destroyable";
import { array } from "@ember/helper";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import EmbedMode from "discourse/lib/embed-mode";
import discourseLater from "discourse/lib/later";
import { headerOffset } from "discourse/lib/offset-calculator";
import SwipeEvents, {
  getMaxAnimationTimeMs,
  shouldCloseMenu,
} from "discourse/lib/swipe-events";
import TrackedMediaQuery from "discourse/lib/tracked-media-query";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dCloseOnClickOutside from "discourse/ui-kit/modifiers/d-close-on-click-outside";
import JumpToPost from "./modal/jump-to-post";

const MIN_WIDTH_TIMELINE = 925;
const MIN_HEIGHT_TIMELINE = 325;

// State shared with the yielded block (the timeline / progress bar). Derived
// values read through injected fetchers rather than a back-reference to the
// component, so tracking is preserved without coupling.
class TopicNavigationInfo {
  @tracked topicProgressExpanded = false;
  @tracked prevEvent = null;

  #postCountFetcher;
  #renderTimelineFetcher;

  constructor(postCountFetcher, renderTimelineFetcher) {
    this.#postCountFetcher = postCountFetcher;
    this.#renderTimelineFetcher = renderTimelineFetcher;
  }

  get renderTimeline() {
    return this.#renderTimelineFetcher();
  }

  get withTopicProgress() {
    return !this.renderTimeline && this.#postCountFetcher() > 1;
  }
}

export default class TopicNavigation extends Component {
  @service appEvents;
  @service composer;
  @service modal;
  @service site;

  @tracked heightQuery = null;
  heightThreshold = null;
  info = new TopicNavigationInfo(
    () => this.args.topic.posts_count,
    () => this.renderTimeline
  );

  widthQuery = this.setupWidthQuery();

  movingElement = null;
  pxClosed = 0;

  setupSwipe = modifierFn((element) => {
    if (!this.site.mobileView) {
      return;
    }

    const swipeEvents = new SwipeEvents(element);
    swipeEvents.addTouchListeners();
    element.addEventListener("swipestart", this.onSwipeStart);
    element.addEventListener("swipeend", this.onSwipeEnd);
    element.addEventListener("swipecancel", this.onSwipeCancel);
    element.addEventListener("swipe", this.onSwipe);

    return () => {
      element.removeEventListener("swipestart", this.onSwipeStart);
      element.removeEventListener("swipeend", this.onSwipeEnd);
      element.removeEventListener("swipecancel", this.onSwipeCancel);
      element.removeEventListener("swipe", this.onSwipe);
      swipeEvents.removeTouchListeners();
    };
  });

  constructor() {
    super(...arguments);
    this.setupAppEvents();
    this.rebuildHeightQuery();
  }

  setupAppEvents() {
    this.appEvents
      .on("topic:current-post-scrolled", this.topicScrolled)
      .on("topic:jump-to-post", this.collapseFullscreen)
      .on("topic:keyboard-trigger", this.keyboardTrigger)
      .on("topic:toggle-progress-expansion", this.toggleProgressExpansion)
      .on("composer:opened", this.rebuildHeightQuery)
      .on("composer:resize-ended", this.rebuildHeightQuery)
      .on("composer:closed", this.rebuildHeightQuery)
      .on("composer:preview-toggled", this.rebuildHeightQuery);

    registerDestructor(this, () => {
      this.appEvents
        .off("topic:current-post-scrolled", this.topicScrolled)
        .off("topic:jump-to-post", this.collapseFullscreen)
        .off("topic:keyboard-trigger", this.keyboardTrigger)
        .off("topic:toggle-progress-expansion", this.toggleProgressExpansion)
        .off("composer:opened", this.rebuildHeightQuery)
        .off("composer:resize-ended", this.rebuildHeightQuery)
        .off("composer:closed", this.rebuildHeightQuery)
        .off("composer:preview-toggled", this.rebuildHeightQuery);

      this.heightQuery?.teardown();
    });
  }

  setupWidthQuery() {
    const query = new TrackedMediaQuery(`(min-width: ${MIN_WIDTH_TIMELINE}px)`);
    registerDestructor(this, () => query.teardown());
    return query;
  }

  get renderTimeline() {
    // Expanded == mobile fullscreen mode; always render.
    if (this.info.topicProgressExpanded) {
      return true;
    }

    if (this.site.mobileView || EmbedMode.enabled) {
      return false;
    }

    if (!this.widthQuery.matches) {
      return false;
    }

    // If composer is open, check we have enough vertical space.
    if (this.composer.isPreviewVisible) {
      return this.heightQuery?.matches ?? false;
    }

    return true;
  }

  // The height threshold depends on the (untracked, user-resizable) composer and
  // header heights, so it can't be a static media query. We recompute it from
  // the composer events and cache the matching `TrackedMediaQuery`, rebuilding
  // only when the threshold actually changes.
  @bind
  rebuildHeightQuery() {
    const threshold = this.composer.isPreviewVisible
      ? MIN_HEIGHT_TIMELINE +
        (document.querySelector("#reply-control")?.offsetHeight || 0) +
        headerOffset()
      : null;

    if (threshold === this.heightThreshold) {
      return;
    }

    this.heightThreshold = threshold;
    this.heightQuery?.teardown();
    this.heightQuery =
      threshold === null
        ? null
        : new TrackedMediaQuery(`(min-height: ${threshold}px)`);
  }

  @bind
  topicScrolled(event) {
    this.info.prevEvent = event;
  }

  @bind
  toggleProgressExpansion() {
    this.info.topicProgressExpanded = !this.info.topicProgressExpanded;
  }

  @bind
  closeOnClickOutside() {
    if (this.info.topicProgressExpanded) {
      this.collapseFullscreen();
    }
  }

  @bind
  collapseFullscreen(postId, delay = 500) {
    if (!this.info.topicProgressExpanded) {
      return;
    }

    document
      .querySelectorAll(".timeline-fullscreen")
      .forEach((el) => el.classList.remove("show"));

    discourseLater(() => {
      if (isDestroying(this) || isDestroyed(this)) {
        return;
      }
      this.info.topicProgressExpanded = false;
    }, delay);
  }

  @bind
  keyboardTrigger(e) {
    if (e.type === "jump") {
      this.modal.show(JumpToPost, {
        model: {
          topic: this.args.topic,
          jumpToIndex: this.args.jumpToIndex,
          jumpToDate: this.args.jumpToDate,
        },
      });
    }
  }

  @bind
  onSwipeStart(event) {
    const e = event.detail;
    const target = e.originalEvent.target;

    if (
      target.classList.contains("docked") ||
      !target.closest(".timeline-container")
    ) {
      event.preventDefault();
      return;
    }

    e.originalEvent.preventDefault();
    const centeredElement = document.elementFromPoint(e.center.x, e.center.y);
    if (centeredElement.closest(".timeline-scrollarea-wrapper")) {
      event.preventDefault();
    } else if (e.direction === "up" || e.direction === "down") {
      this.movingElement = document.querySelector(".timeline-container");
    }
  }

  @bind
  onSwipeCancel() {
    const durationMs = getMaxAnimationTimeMs();
    const timelineContainer = document.querySelector(".timeline-container");
    timelineContainer.animate([{ transform: `translate3d(0, 0, 0)` }], {
      duration: durationMs,
      fill: "forwards",
      easing: "ease-out",
    });
  }

  @bind
  onSwipeEnd(event) {
    const e = event.detail;
    const timelineContainer = document.querySelector(".timeline-container");
    const maxOffset = timelineContainer.offsetHeight;

    let durationMs;
    if (shouldCloseMenu(e, "bottom")) {
      const distancePx = maxOffset - this.pxClosed;
      durationMs = getMaxAnimationTimeMs(distancePx / Math.abs(e.velocityY));
      timelineContainer
        .animate([{ transform: `translate3d(0, ${maxOffset}px, 0)` }], {
          duration: durationMs,
          fill: "forwards",
        })
        .finished.then(() => this.collapseFullscreen(null, 0));
    } else {
      const distancePx = this.pxClosed;
      durationMs = getMaxAnimationTimeMs(distancePx / Math.abs(e.velocityY));
      timelineContainer.animate([{ transform: `translate3d(0, 0, 0)` }], {
        duration: durationMs,
        fill: "forwards",
        easing: "ease-out",
      });
    }
  }

  @bind
  onSwipe(event) {
    const e = event.detail;
    e.originalEvent.preventDefault();
    this.pxClosed = Math.max(0, e.deltaY);

    this.movingElement.animate(
      [{ transform: `translate3d(0, ${this.pxClosed}px, 0)` }],
      { fill: "forwards" }
    );
  }

  <template>
    <div
      class={{dConcatClass
        (if this.info.topicProgressExpanded "topic-progress-expanded")
        (if this.info.renderTimeline "with-timeline")
        (if this.info.withTopicProgress "with-topic-progress")
      }}
      ...attributes
      {{this.setupSwipe}}
      {{dCloseOnClickOutside this.closeOnClickOutside}}
    >
      {{! Fully rerender when topic changes (see 4f328089d6f). }}
      {{#each (array @topic) key="id"}}
        {{yield this.info this.toggleProgressExpansion}}
      {{/each}}
    </div>
  </template>
}
