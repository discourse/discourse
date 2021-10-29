import discourseComputed, { bind } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import I18n from "I18n";
import { alias } from "@ember/object/computed";
import { scheduleOnce } from "@ember/runloop";

export default Component.extend({
  elementId: "topic-progress-wrapper",
  classNameBindings: ["docked"],
  docked: false,
  progressPosition: null,
  postStream: alias("topic.postStream"),
  _streamPercentage: null,

  @discourseComputed("progressPosition")
  jumpTopDisabled(progressPosition) {
    return progressPosition <= 3;
  },

  @discourseComputed(
    "postStream.filteredPostsCount",
    "topic.highest_post_number",
    "progressPosition"
  )
  jumpBottomDisabled(filteredPostsCount, highestPostNumber, progressPosition) {
    return (
      progressPosition >= filteredPostsCount ||
      progressPosition >= highestPostNumber
    );
  },

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

  @discourseComputed("hugeNumberOfPosts", "topic.highest_post_number")
  jumpToBottomTitle(hugeNumberOfPosts, highestPostNumber) {
    if (hugeNumberOfPosts) {
      return I18n.t("topic.progress.jump_bottom_with_number", {
        post_number: highestPostNumber,
      });
    } else {
      return I18n.t("topic.progress.jump_bottom");
    }
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
  },

  willDestroyElement() {
    this._super(...arguments);
    this._topicBottomObserver?.disconnect();
    this.appEvents
      .off("composer:resized", this, this._composerEvent)
      .off("topic:current-post-scrolled", this, this._topicScrolled);
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
    const composerH =
      document.querySelector("#reply-control")?.clientHeight || 0;

    return new IntersectionObserver(this._intersectionHandler, {
      threshold: 0.1,
      rootMargin: `0px 0px -${composerH}px 0px`,
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
    if (entries[0].isIntersecting === true) {
      this.set("docked", true);
    } else {
      if (entries[0].boundingClientRect.top > 0) {
        this.set("docked", false);
        const wrapper = document.querySelector("#topic-progress-wrapper");
        const composerH =
          document.querySelector("#reply-control")?.clientHeight || 0;
        if (composerH === 0) {
          const filteredPostsHeight =
            document.querySelector(".posts-filtered-notice")?.clientHeight || 0;
          filteredPostsHeight === 0
            ? wrapper.style.removeProperty("bottom")
            : wrapper.style.setProperty("bottom", `${filteredPostsHeight}px`);
        } else {
          wrapper.style.setProperty("bottom", `${composerH}px`);
        }
      }
    }
  },

  click(e) {
    if (e.target.closest("#topic-progress")) {
      this.send("toggleExpansion");
    }
  },

  actions: {
    toggleExpansion() {
      this.toggleProperty("expanded");
    },

    goBack() {
      this.attrs.jumpToPost(this.get("topic.last_read_post_number"));
    },
  },
});
