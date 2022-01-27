import discourseComputed, { bind } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { later, scheduleOnce } from "@ember/runloop";
import { action } from "@ember/object";
import { isTesting } from "discourse-common/config/environment";

const CSS_TRANSITION_DELAY = isTesting() ? 0 : 500;

export default Component.extend({
  elementId: "topic-progress-wrapper",
  classNameBindings: ["docked", "withTransitions"],
  docked: false,
  withTransitions: null,
  progressPosition: null,
  postStream: alias("topic.postStream"),
  _streamPercentage: null,

  @discourseComputed(
    "postStream.loaded",
    "topic.currentPost",
    "postStream.filteredPostsCount"
  )
  hideProgress(loaded, currentPost, filteredPostsCount) {
    const hideOnShortStream = !this.site.mobileView && filteredPostsCount < 2;
    return !loaded || !currentPost || hideOnShortStream;
  },

  @discourseComputed("postStream.filteredPostsCount")
  hugeNumberOfPosts(filteredPostsCount) {
    return (
      filteredPostsCount >= this.siteSettings.short_progress_text_threshold
    );
  },

  @discourseComputed("progressPosition", "topic.last_read_post_id")
  showBackButton(position, lastReadId) {
    if (!lastReadId) {
      return;
    }

    const stream = this.get("postStream.stream");
    const readPos = stream.indexOf(lastReadId) || 0;
    return readPos < stream.length - 1 && readPos > position;
  },

  _topicScrolled(event) {
    if (this.docked) {
      this.setProperties({
        progressPosition: this.get("postStream.filteredPostsCount"),
        _streamPercentage: 100,
      });
    } else {
      this.setProperties({
        progressPosition: event.postIndex,
        _streamPercentage: (event.percent * 100).toFixed(2),
      });
    }
  },

  @discourseComputed("_streamPercentage")
  progressStyle(_streamPercentage) {
    return `--progress-bg-width: ${_streamPercentage || 0}%`;
  },

  didInsertElement() {
    this._super(...arguments);

    this.appEvents
      .on("composer:resized", this, this._composerEvent)
      .on("topic:current-post-scrolled", this, this._topicScrolled);

    if (this.prevEvent) {
      scheduleOnce("afterRender", this, this._topicScrolled, this.prevEvent);
    }
    scheduleOnce("afterRender", this, this._startObserver);

    // start CSS transitions a tiny bit later
    // to avoid jumpiness on initial topic load
    later(this._addCssTransitions, CSS_TRANSITION_DELAY);
  },

  willDestroyElement() {
    this._super(...arguments);
    this._topicBottomObserver?.disconnect();
    this.appEvents
      .off("composer:resized", this, this._composerEvent)
      .off("topic:current-post-scrolled", this, this._topicScrolled);
  },

  @bind
  _addCssTransitions() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }
    this.set("withTransitions", true);
  },

  _startObserver() {
    if ("IntersectionObserver" in window) {
      this._topicBottomObserver = this._setupObserver();
      this._topicBottomObserver.observe(
        document.querySelector("#topic-bottom")
      );
    }
  },

  _setupObserver() {
    // minimum 50px here ensures element is not docked when
    // scrolling down quickly, it causes post stream refresh loop
    // on Android
    const bottomIntersectionMargin =
      document.querySelector("#reply-control")?.clientHeight || 50;

    return new IntersectionObserver(this._intersectionHandler, {
      threshold: 1,
      rootMargin: `0px 0px -${bottomIntersectionMargin}px 0px`,
    });
  },

  _composerEvent() {
    // reinitializing needed to account for composer height
    // might be no longer necessary if IntersectionObserver API supports dynamic rootMargin
    // see https://github.com/w3c/IntersectionObserver/issues/428
    if ("IntersectionObserver" in window) {
      this._topicBottomObserver?.disconnect();
      this._startObserver();
    }
  },

  @bind
  _intersectionHandler(entries) {
    if (!this.element || this.isDestroying || this.isDestroyed) {
      return;
    }

    const composerH =
      document.querySelector("#reply-control")?.clientHeight || 0;

    // on desktop, pin this element to the composer
    // otherwise the grid layout will change too much when toggling the composer
    // and jitter when the viewport is near the topic bottom
    if (!this.site.mobileView && composerH) {
      this.set("docked", false);
      this.element.style.setProperty("bottom", `${composerH}px`);
      return;
    }

    if (entries[0].isIntersecting === true) {
      this.set("docked", true);
      this.element.style.removeProperty("bottom");
    } else {
      if (entries[0].boundingClientRect.top > 0) {
        this.set("docked", false);
        if (composerH === 0) {
          const filteredPostsHeight =
            document.querySelector(".posts-filtered-notice")?.clientHeight || 0;
          filteredPostsHeight === 0
            ? this.element.style.removeProperty("bottom")
            : this.element.style.setProperty(
                "bottom",
                `${filteredPostsHeight}px`
              );
        } else {
          this.element.style.setProperty("bottom", `${composerH}px`);
        }
      }
    }
  },

  click(e) {
    if (e.target.closest("#topic-progress")) {
      this.toggleProperty("expanded");
    }
  },

  @action
  goBack() {
    this.attrs.jumpToPost(this.get("topic.last_read_post_number"));
  },
});
