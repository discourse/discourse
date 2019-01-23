import { getOwner } from "discourse-common/lib/get-owner";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  elementId: "topic-progress-wrapper",
  classNameBindings: ["docked"],
  docked: false,
  progressPosition: null,
  postStream: Ember.computed.alias("topic.postStream"),
  _streamPercentage: null,

  @computed("progressPosition")
  jumpTopDisabled(progressPosition) {
    return progressPosition <= 3;
  },

  @computed(
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

  @computed(
    "postStream.loaded",
    "topic.currentPost",
    "postStream.filteredPostsCount"
  )
  hideProgress(loaded, currentPost, filteredPostsCount) {
    return (
      !loaded ||
      !currentPost ||
      (!this.site.mobileView && filteredPostsCount < 2)
    );
  },

  @computed("postStream.filteredPostsCount")
  hugeNumberOfPosts(filteredPostsCount) {
    return (
      filteredPostsCount >= this.siteSettings.short_progress_text_threshold
    );
  },

  @computed("hugeNumberOfPosts", "topic.highest_post_number")
  jumpToBottomTitle(hugeNumberOfPosts, highestPostNumber) {
    if (hugeNumberOfPosts) {
      return I18n.t("topic.progress.jump_bottom_with_number", {
        post_number: highestPostNumber
      });
    } else {
      return I18n.t("topic.progress.jump_bottom");
    }
  },

  @computed("progressPosition", "topic.last_read_post_id")
  showBackButton(position, lastReadId) {
    if (!lastReadId) {
      return;
    }

    const stream = this.get("postStream.stream");
    const readPos = stream.indexOf(lastReadId) || 0;
    return readPos < stream.length - 1 && readPos > position;
  },

  @observes("postStream.stream.[]")
  _updateBar() {
    Ember.run.scheduleOnce("afterRender", this, this._updateProgressBar);
  },

  _topicScrolled(event) {
    if (this.get("docked")) {
      this.set("progressPosition", this.get("postStream.filteredPostsCount"));
      this._streamPercentage = 1.0;
    } else {
      this.set("progressPosition", event.postIndex);
      this._streamPercentage = event.percent;
    }

    this._updateBar();
  },

  didInsertElement() {
    this._super(...arguments);

    this.appEvents
      .on("composer:will-open", this, this._dock)
      .on("composer:resized", this, this._dock)
      .on("composer:closed", this, this._dock)
      .on("topic:scrolled", this, this._dock)
      .on("topic:current-post-scrolled", this, this._topicScrolled);

    const prevEvent = this.get("prevEvent");
    if (prevEvent) {
      Ember.run.scheduleOnce(
        "afterRender",
        this,
        this._topicScrolled,
        prevEvent
      );
    } else {
      Ember.run.scheduleOnce("afterRender", this, this._updateProgressBar);
    }
    Ember.run.scheduleOnce("afterRender", this, this._dock);
  },

  willDestroyElement() {
    this._super(...arguments);
    this.appEvents
      .off("composer:will-open", this, this._dock)
      .off("composer:resized", this, this._dock)
      .off("composer:closed", this, this._dock)
      .off("topic:scrolled", this, this._dock)
      .off("topic:current-post-scrolled", this, this._topicScrolled);
  },

  _updateProgressBar() {
    if (this.isDestroyed || this.isDestroying) {
      return;
    }

    const $topicProgress = this.$("#topic-progress");
    // speeds up stuff, bypass jquery slowness and extra checks
    if (!this._totalWidth) {
      this._totalWidth = $topicProgress[0].offsetWidth;
    }

    // Only show percentage once we have one
    if (!this._streamPercentage) {
      return;
    }

    const totalWidth = this._totalWidth;
    const progressWidth = (this._streamPercentage || 0) * totalWidth;
    const borderSize = progressWidth === totalWidth ? "0px" : "1px";

    const $bg = $topicProgress.find(".bg");
    if ($bg.length === 0) {
      const style = `border-right-width: ${borderSize}; width: ${progressWidth}px`;
      $topicProgress.append(`<div class='bg' style="${style}">&nbsp;</div>`);
    } else {
      $bg.css("border-right-width", borderSize).width(progressWidth - 2);
    }
  },

  _dock() {
    const $wrapper = this.$();
    if (!$wrapper || $wrapper.length === 0) return;

    const offset = window.pageYOffset || $("html").scrollTop(),
      progressHeight = this.site.mobileView ? 0 : $("#topic-progress").height(),
      maximumOffset = $("#topic-bottom").offset().top + progressHeight,
      windowHeight = $(window).height(),
      bodyHeight = $("body").height(),
      composerHeight = $("#reply-control").height() || 0,
      isDocked = offset >= maximumOffset - windowHeight + composerHeight,
      bottom = bodyHeight - maximumOffset;

    if (composerHeight > 0) {
      $wrapper.css("bottom", isDocked ? bottom : composerHeight);
    } else {
      $wrapper.css("bottom", isDocked ? bottom : "");
    }

    this.set("docked", isDocked);

    const $replyArea = $("#reply-control .reply-area");
    if ($replyArea && $replyArea.length > 0) {
      $wrapper.css("right", `${$replyArea.offset().left}px`);
    } else {
      $wrapper.css("right", "1em");
    }

    // switch mobile scroll logo at the very bottom of topics
    if (this.site.mobileView) {
      const isIOS = this.capabilities.isIOS,
        switchHeight = bodyHeight - offset - windowHeight,
        appEvents = getOwner(this).lookup("app-events:main");

      if (isIOS && switchHeight < -10) {
        // match elastic-scroll behaviour in iOS
        setTimeout(function() {
          appEvents.trigger("header:hide-topic");
        }, 300);
      } else if (!isIOS && switchHeight < 5) {
        // normal switch for everyone else
        setTimeout(function() {
          appEvents.trigger("header:hide-topic");
        }, 300);
      }
    }
  },

  click(e) {
    if ($(e.target).closest("#topic-progress").length) {
      this.send("toggleExpansion");
    }
  },

  actions: {
    toggleExpansion() {
      this.toggleProperty("expanded");
    },

    goBack() {
      this.attrs.jumpToPost(this.get("topic.last_read_post_number"));
    }
  }
});
