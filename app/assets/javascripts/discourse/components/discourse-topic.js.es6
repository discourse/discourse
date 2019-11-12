import { alias } from "@ember/object/computed";
import { throttle } from "@ember/runloop";
import { schedule } from "@ember/runloop";
import { scheduleOnce } from "@ember/runloop";
import { later } from "@ember/runloop";
import Component from "@ember/component";
import DiscourseURL from "discourse/lib/url";
import AddArchetypeClass from "discourse/mixins/add-archetype-class";
import ClickTrack from "discourse/lib/click-track";
import Scrolling from "discourse/mixins/scrolling";
import MobileScrollDirection from "discourse/mixins/mobile-scroll-direction";
import { observes } from "discourse-common/utils/decorators";

const MOBILE_SCROLL_DIRECTION_CHECK_THROTTLE = 300;

function highlight(postNumber) {
  const $contents = $(`#post_${postNumber} .topic-body`);

  $contents.addClass("highlighted");
  $contents.on("animationend", () => $contents.removeClass("highlighted"));
}

export default Component.extend(
  AddArchetypeClass,
  Scrolling,
  MobileScrollDirection,
  {
    userFilters: alias("topic.userFilters"),
    classNameBindings: [
      "multiSelect",
      "topic.archetype",
      "topic.is_warning",
      "topic.category.read_restricted:read_restricted",
      "topic.deleted:deleted-topic",
      "topic.categoryClass",
      "topic.tagClasses"
    ],
    menuVisible: true,
    SHORT_POST: 1200,

    postStream: alias("topic.postStream"),
    archetype: alias("topic.archetype"),
    dockAt: 0,

    _lastShowTopic: null,

    mobileScrollDirection: null,
    pauseHeaderTopicUpdate: false,

    @observes("enteredAt")
    _enteredTopic() {
      // Ember is supposed to only call observers when values change but something
      // in our view set up is firing this observer with the same value. This check
      // prevents scrolled from being called twice.
      const enteredAt = this.enteredAt;
      if (enteredAt && this.lastEnteredAt !== enteredAt) {
        this._lastShowTopic = null;
        schedule("afterRender", () => this.scrolled());
        this.set("lastEnteredAt", enteredAt);
      }
    },

    _highlightPost(postNumber) {
      scheduleOnce("afterRender", null, highlight, postNumber);
    },

    _hideTopicInHeader() {
      this.appEvents.trigger("header:hide-topic");
      this._lastShowTopic = false;
    },

    _showTopicInHeader(topic) {
      if (this.pauseHeaderTopicUpdate) return;
      this.appEvents.trigger("header:show-topic", topic);
      this._lastShowTopic = true;
    },

    _updateTopic(topic, debounceDuration) {
      if (topic === null) {
        this._hideTopicInHeader();

        if (debounceDuration && !this.pauseHeaderTopicUpdate) {
          this.pauseHeaderTopicUpdate = true;
          this._lastShowTopic = true;

          later(() => {
            this._lastShowTopic = false;
            this.pauseHeaderTopicUpdate = false;
          }, debounceDuration);
        }

        return;
      }

      const offset = window.pageYOffset || $("html").scrollTop();
      this._lastShowTopic = this.shouldShowTopicInHeader(topic, offset);

      if (this._lastShowTopic) {
        this._showTopicInHeader(topic);
      } else {
        this._hideTopicInHeader();
      }
    },

    didInsertElement() {
      this._super(...arguments);
      this.bindScrolling({ name: "topic-view" });

      $(window).on("resize.discourse-on-scroll", () => this.scrolled());

      $(this.element).on(
        "click.discourse-redirect",
        ".cooked a, a.track-link",
        function(e) {
          return ClickTrack.trackClick(e);
        }
      );

      this.appEvents.on("discourse:focus-changed", this, "gotFocus");
      this.appEvents.on("post:highlight", this, "_highlightPost");
      this.appEvents.on("header:update-topic", this, "_updateTopic");
    },

    willDestroyElement() {
      this._super(...arguments);
      this.unbindScrolling("topic-view");
      $(window).unbind("resize.discourse-on-scroll");

      // Unbind link tracking
      $(this.element).off(
        "click.discourse-redirect",
        ".cooked a, a.track-link"
      );

      this.resetExamineDockCache();

      // this happens after route exit, stuff could have trickled in
      this._hideTopicInHeader();
      this.appEvents.off("discourse:focus-changed", this, "gotFocus");
      this.appEvents.off("post:highlight", this, "_highlightPost");
      this.appEvents.off("header:update-topic", this, "_updateTopic");
    },

    gotFocus(hasFocus) {
      if (hasFocus) {
        this.scrolled();
      }
    },

    resetExamineDockCache() {
      this.set("dockAt", 0);
    },

    shouldShowTopicInHeader(topic, offset) {
      // On mobile, we show the header topic if the user has scrolled past the topic
      // title and the current scroll direction is down
      // On desktop the user only needs to scroll past the topic title.
      return (
        offset > this.dockAt &&
        (!this.site.mobileView || this.mobileScrollDirection === "down")
      );
    },
    // The user has scrolled the window, or it is finished rendering and ready for processing.
    scrolled() {
      if (this.isDestroyed || this.isDestroying || this._state !== "inDOM") {
        return;
      }

      const offset = window.pageYOffset || $("html").scrollTop();
      if (this.dockAt === 0) {
        const title = $("#topic-title");
        if (title && title.length === 1) {
          this.set("dockAt", title.offset().top);
        }
      }

      this.set("hasScrolled", offset > 0);

      const topic = this.topic;
      const showTopic = this.shouldShowTopicInHeader(topic, offset);

      if (showTopic !== this._lastShowTopic) {
        if (showTopic) {
          this._showTopicInHeader(topic);
        } else {
          if (!DiscourseURL.isJumpScheduled()) {
            const loadingNear = topic.get("postStream.loadingNearPost") || 1;
            if (loadingNear === 1) {
              this._hideTopicInHeader();
            }
          }
        }
      }

      // Since the user has scrolled, we need to check the scroll direction on mobile.
      // We use throttle instead of debounce because we want the switch to occur
      // at the start of the scroll. This feels a lot more snappy compared to waiting
      // for the scroll to end if we debounce.
      if (this.site.mobileView && this.hasScrolled) {
        throttle(
          this,
          this.calculateDirection,
          offset,
          MOBILE_SCROLL_DIRECTION_CHECK_THROTTLE
        );
      }

      // Trigger a scrolled event
      this.appEvents.trigger("topic:scrolled", offset);
    },

    // We observe the scroll direction on mobile and if it's down, we show the topic
    // in the header, otherwise, we hide it.
    @observes("mobileScrollDirection")
    toggleMobileHeaderTopic() {
      return this.appEvents.trigger(
        "header:update-topic",
        this.mobileScrollDirection === "down" ? this.topic : null
      );
    }
  }
);
