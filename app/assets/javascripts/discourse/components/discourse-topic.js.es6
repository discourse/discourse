import DiscourseURL from "discourse/lib/url";
import AddArchetypeClass from "discourse/mixins/add-archetype-class";
import ClickTrack from "discourse/lib/click-track";
import Scrolling from "discourse/mixins/scrolling";
import MobileScrollDirection from "discourse/mixins/mobile-scroll-direction";
import { observes } from "ember-addons/ember-computed-decorators";

const MOBILE_SCROLL_DIRECTION_CHECK_THROTTLE = 300;

function highlight(postNumber) {
  const $contents = $(`#post_${postNumber} .topic-body`);

  $contents.addClass("highlighted");
  $contents.on("animationend", () => $contents.removeClass("highlighted"));
}

export default Ember.Component.extend(
  AddArchetypeClass,
  Scrolling,
  MobileScrollDirection,
  {
    userFilters: Ember.computed.alias("topic.userFilters"),
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

    postStream: Ember.computed.alias("topic.postStream"),
    archetype: Ember.computed.alias("topic.archetype"),
    dockAt: 0,

    _lastShowTopic: null,

    mobileScrollDirection: null,

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

    _highlightPost(postNumber) {
      Ember.run.scheduleOnce("afterRender", null, highlight, postNumber);
    },

    _updateTopic(topic) {
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
    },

    didInsertElement() {
      this._super(...arguments);
      this.bindScrolling({ name: "topic-view" });

      $(window).on("resize.discourse-on-scroll", () => this.scrolled());

      this.$().on(
        "click.discourse-redirect",
        ".cooked a, a.track-link",
        function(e) {
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

      this.appEvents.on("post:highlight", this, "_highlightPost");

      this.appEvents.on("header:update-topic", this, "_updateTopic");
    },

    willDestroyElement() {
      this._super(...arguments);
      this.unbindScrolling("topic-view");
      $(window).unbind("resize.discourse-on-scroll");

      // Unbind link tracking
      this.$().off("click.discourse-redirect", ".cooked a, a.track-link");

      this.resetExamineDockCache();

      // this happens after route exit, stuff could have trickled in
      this.appEvents.trigger("header:hide-topic");
      this.appEvents.off("post:highlight", this, "_highlightPost");
      this.appEvents.off("header:update-topic", this, "_updateTopic");
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
        this.mobileScrollDirection === "down" ? this.get("topic") : null
      );
    }
  }
);
