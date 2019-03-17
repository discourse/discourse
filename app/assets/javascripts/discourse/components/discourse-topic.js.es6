import DiscourseURL from "discourse/lib/url";
import AddArchetypeClass from "discourse/mixins/add-archetype-class";
import ClickTrack from "discourse/lib/click-track";
import Scrolling from "discourse/mixins/scrolling";
import { selectedText } from "discourse/lib/utilities";
import { observes } from "ember-addons/ember-computed-decorators";

const MOBILE_SCROLL_DIRECTION_CHECK_THROTTLE = 100;
// Small buffer so that very tiny scrolls don't trigger mobile header switch
const MOBILE_SCROLL_TOLERANCE = 5;

function highlight(postNumber) {
  const $contents = $(`#post_${postNumber} .topic-body`);

  $contents.addClass("highlighted");
  $contents.on("animationend", () => $contents.removeClass("highlighted"));
}

export default Ember.Component.extend(AddArchetypeClass, Scrolling, {
  userFilters: Ember.computed.alias("topic.userFilters"),
  classNameBindings: [
    "multiSelect",
    "topic.archetype",
    "topic.is_warning",
    "topic.category.read_restricted:read_restricted",
    "topic.deleted:deleted-topic",
    "topic.categoryClass"
  ],
  menuVisible: true,
  SHORT_POST: 1200,

  postStream: Ember.computed.alias("topic.postStream"),
  archetype: Ember.computed.alias("topic.archetype"),
  dockAt: 0,

  _lastShowTopic: null,

  mobileScrollDirection: null,
  _mobileLastScroll: null,

  @observes("enteredAt")
  _enteredTopic() {
    // Ember is supposed to only call observers when values change but something
    // in our view set up is firing this observer with the same value. This check
    // prevents scrolled from being called twice.
    const enteredAt = this.get("enteredAt");
    if (enteredAt && this.get("lastEnteredAt") !== enteredAt) {
      this._lastShowTopic = null;
      Ember.run.schedule("afterRender", () => this.scrolled());
      this.set("lastEnteredAt", enteredAt);
    }
  },

  didInsertElement() {
    this._super(...arguments);
    this.bindScrolling({ name: "topic-view" });

    $(window).on("resize.discourse-on-scroll", () => this.scrolled());

    this.$().on(
      "mouseup.discourse-redirect",
      ".cooked a, a.track-link",
      function(e) {
        // bypass if we are selecting stuff
        const selection = window.getSelection && window.getSelection();
        if (selection.type === "Range" || selection.rangeCount > 0) {
          if (selectedText() !== "") {
            return true;
          }
        }

        const $target = $(e.target);
        if (
          $target.hasClass("mention") ||
          $target.parents(".expanded-embed").length
        ) {
          return false;
        }

        return ClickTrack.trackClick(e);
      }
    );

    this.appEvents.on("post:highlight", postNumber => {
      Ember.run.scheduleOnce("afterRender", null, highlight, postNumber);
    });

    this.appEvents.on("header:update-topic", topic => {
      if (topic === null) {
        this._lastShowTopic = false;
        this.appEvents.trigger("header:hide-topic");
        return;
      }

      const offset = window.pageYOffset || $("html").scrollTop();
      this._lastShowTopic = this.showTopicInHeader(topic, offset);

      if (this._lastShowTopic) {
        this.appEvents.trigger("header:show-topic", topic);
      } else {
        this.appEvents.trigger("header:hide-topic");
      }
    });
  },

  willDestroyElement() {
    this._super(...arguments);
    this.unbindScrolling("topic-view");
    $(window).unbind("resize.discourse-on-scroll");

    // Unbind link tracking
    this.$().off("mouseup.discourse-redirect", ".cooked a, a.track-link");

    this.resetExamineDockCache();

    // this happens after route exit, stuff could have trickled in
    this.appEvents.trigger("header:hide-topic");
    this.appEvents.off("post:highlight");
    this.appEvents.off("header:update-topic");
  },

  @observes("Discourse.hasFocus")
  gotFocus() {
    if (Discourse.get("hasFocus")) {
      this.scrolled();
    }
  },

  resetExamineDockCache() {
    this.set("dockAt", 0);
  },

  showTopicInHeader(topic, offset) {
    // On mobile, we show the header topic if the user has scrolled past the topic
    // title and the current scroll direction is down
    // On desktop the user only needs to scroll past the topic title.

    return this.site.mobileView
      ? offset > this.dockAt && this.mobileScrollDirection === "down"
      : offset > this.dockAt;
  },
  // The user has scrolled the window, or it is finished rendering and ready for processing.
  scrolled() {
    if (this.isDestroyed || this.isDestroying || this._state !== "inDOM") {
      return;
    }

    const offset = window.pageYOffset || $("html").scrollTop();
    if (this.get("dockAt") === 0) {
      const title = $("#topic-title");
      if (title && title.length === 1) {
        this.set("dockAt", title.offset().top);
      }
    }

    this.set("hasScrolled", offset > 0);

    const topic = this.get("topic");
    const showTopic = this.showTopicInHeader(topic, offset);
    if (showTopic !== this._lastShowTopic) {
      if (showTopic) {
        this.appEvents.trigger("header:show-topic", topic);
        this._lastShowTopic = true;
      } else {
        if (!DiscourseURL.isJumpScheduled()) {
          const loadingNear = topic.get("postStream.loadingNearPost") || 1;
          if (loadingNear === 1) {
            this.appEvents.trigger("header:hide-topic");
            this._lastShowTopic = false;
          }
        }
      }
    }

    // Since the user has scrolled, we need to check the scroll direction on mobile.
    // We use throttle instead of debounce because we want the switch to occur
    // at the start of the scroll. This feels a lot more snappy compared to waiting
    // for the scroll to end if we debounce.
    if (this.site.mobileView && this.hasScrolled) {
      Ember.run.throttle(
        this,
        this._mobileScrollDirectionCheck,
        offset,
        MOBILE_SCROLL_DIRECTION_CHECK_THROTTLE
      );
    }

    // Trigger a scrolled event
    this.appEvents.trigger("topic:scrolled", offset);
  },

  _mobileScrollDirectionCheck(offset) {
    // Difference between this scroll and the one before it.
    const delta = parseInt(offset - this._mobileLastScroll, 10);

    // This is a tiny scroll, so we ignore it.
    if (delta <= MOBILE_SCROLL_TOLERANCE && delta >= -MOBILE_SCROLL_TOLERANCE)
      return;

    const prevDirection = this.mobileScrollDirection;
    const currDirection = delta > 0 ? "down" : "up";

    if (currDirection === "down" && prevDirection !== "down") {
      // Delta is positive so the direction is down
      this.set("mobileScrollDirection", "down");
    } else if (currDirection === "up" && prevDirection !== "up") {
      // Delta is negative so the direction is up
      this.set("mobileScrollDirection", "up");
    }

    // We store this to compare against it the next time the user scrolls
    this._mobileLastScroll = parseInt(offset, 10);

    // If the user reaches the very bottom of the topic, we want to reset the
    // scroll direction in order for the header to switch back.
    const distanceToTopicBottom = parseInt(
      $("body").height() - offset - $(window).height(),
      10
    );

    // Not at the bottom yet
    if (distanceToTopicBottom > 0) return;

    // We're at the bottom now, so we reset the direction.
    this.set("mobileScrollDirection", null);
  },

  // We observe the scroll direction on mobile and if it's down, we show the topic
  // in the header, otherwise, we hide it.
  @observes("mobileScrollDirection")
  toggleMobileHeaderTopic() {
    return this.mobileScrollDirection === "down"
      ? this.appEvents.trigger("header:update-topic", this.get("topic"))
      : this.appEvents.trigger("header:update-topic", null);
  }
});
