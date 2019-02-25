import MountWidget from "discourse/components/mount-widget";
import Docking from "discourse/mixins/docking";
import { observes } from "ember-addons/ember-computed-decorators";
import optionalService from "discourse/lib/optional-service";

const headerPadding = () => parseInt($("#main-outlet").css("padding-top")) + 3;

export default MountWidget.extend(Docking, {
  adminTools: optionalService(),
  widget: "topic-timeline-container",
  dockBottom: null,
  dockAt: null,

  buildArgs() {
    let attrs = {
      topic: this.get("topic"),
      notificationLevel: this.get("notificationLevel"),
      topicTrackingState: this.topicTrackingState,
      enteredIndex: this.get("enteredIndex"),
      dockAt: this.dockAt,
      dockBottom: this.dockBottom,
      mobileView: this.get("site.mobileView")
    };

    let event = this.get("prevEvent");
    if (event) {
      attrs.enteredIndex = event.postIndex - 1;
    }

    if (this.get("fullscreen")) {
      attrs.fullScreen = true;
      attrs.addShowClass = this.get("addShowClass");
    } else {
      attrs.top = this.dockAt || headerPadding();
    }

    return attrs;
  },

  @observes("topic.highest_post_number", "loading")
  newPostAdded() {
    this.queueRerender(() => this.queueDockCheck());
  },

  @observes("topic.details.notification_level")
  _queueRerender() {
    this.queueRerender();
  },

  dockCheck(info) {
    const mainOffset = $("#main").offset();
    const offsetTop = mainOffset ? mainOffset.top : 0;
    const topicTop = $(".container.posts").offset().top - offsetTop;
    const topicBottom = $("#topic-bottom").offset().top;
    const $timeline = this.$(".timeline-container");
    const timelineHeight = $timeline.height() || 400;
    const footerHeight = $(".timeline-footer-controls").outerHeight(true) || 0;

    const prev = this.dockAt;
    const posTop = headerPadding() + info.offset();
    const pos = posTop + timelineHeight;

    this.dockBottom = false;
    if (posTop < topicTop) {
      this.dockAt = parseInt(topicTop, 10);
    } else if (pos > topicBottom + footerHeight) {
      this.dockAt = parseInt(topicBottom - timelineHeight + footerHeight, 10);
      this.dockBottom = true;
      if (this.dockAt < 0) {
        this.dockAt = 0;
      }
    } else {
      this.dockAt = null;
      this.fastDockAt = parseInt(
        topicBottom - timelineHeight + footerHeight - offsetTop,
        10
      );
    }

    if (this.dockAt !== prev) {
      this.queueRerender();
    }
  },

  didInsertElement() {
    this._super(...arguments);

    if (this.get("fullscreen") && !this.get("addShowClass")) {
      Ember.run.next(() => {
        this.set("addShowClass", true);
        this.queueRerender();
      });
    }

    this.dispatch("topic:current-post-scrolled", "timeline-scrollarea");
  },

  showModerationHistory() {
    this.get("adminTools").showModerationHistory({
      filter: "topic",
      topic_id: this.get("topic.id")
    });
  }
});
