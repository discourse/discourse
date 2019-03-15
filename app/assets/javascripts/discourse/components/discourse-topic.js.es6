import DiscourseURL from "discourse/lib/url";
import AddArchetypeClass from "discourse/mixins/add-archetype-class";
import ClickTrack from "discourse/lib/click-track";
import Scrolling from "discourse/mixins/scrolling";
import { selectedText } from "discourse/lib/utilities";
import { observes } from "ember-addons/ember-computed-decorators";

function highlight(postNumber) {
  const $contents = $(`#post_${postNumber} .topic-body`);

  $contents.addClass("highlighted");
  $contents.on("animationend", () => $contents.removeClass("highlighted"));
}

// used to determine scroll direction on mobile
let lastScroll, scrollDirection, delta;

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
    // setup mobile scroll logo
    if (this.site.mobileView) {
      this.appEvents.on("topic:scrolled", offset =>
        this.mobileScrollGaurd(offset)
      );
      // used to animate header contents on scroll
      this.appEvents.on("header:show-topic", () => {
        $("header.d-header")
          .removeClass("scroll-up")
          .addClass("scroll-down");
      });
      this.appEvents.on("header:hide-topic", () => {
        $("header.d-header")
          .removeClass("scroll-down")
          .addClass("scroll-up");
      });
    }
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
    // mobile scroll logo clean up.
    if (this.site.mobileView) {
      this.appEvents.off("topic:scrolled");
      $("header.d-header").removeClass("scroll-down scroll-up");
    }
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
    // conditions for showing topic title in the header for mobile
    if (
      this.site.mobileView &&
      scrollDirection !== "up" &&
      offset > this.dockAt
    ) {
      return true;
      // condition for desktops
    } else {
      return offset > this.dockAt;
    }
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

    // Trigger a scrolled event
    this.appEvents.trigger("topic:scrolled", offset);
  },

  // determines scroll direction, triggers header topic info on mobile
  // and ensures that the switch happens only once per scroll direction change
  mobileScrollGaurd(offset) {
    // user hasn't scrolled past topic title.
    if (offset < this.dockAt) return;

    delta = offset - lastScroll;
    // 3px buffer so that the switch doesn't happen with tiny scrolls
    if (delta > 3 && scrollDirection !== "down") {
      scrollDirection = "down";
      this.appEvents.trigger("header:show-topic", this.topic);
    } else if (delta < -3 && scrollDirection !== "up") {
      scrollDirection = "up";
      this.appEvents.trigger("header:hide-topic");
    }
    lastScroll = offset;
  }
});
