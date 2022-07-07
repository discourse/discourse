import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";
createWidget("timeline-scroller", {
  tagName: "div.timeline-scroller",
  buildKey: (attrs) => `timeline-scroller-${attrs.topicId}`,

  defaultState() {
    return { dragging: false };
  },

  buildAttributes() {
    return { style: `height: ${SCROLLER_HEIGHT}px` };
  },

  html(attrs, state) {
    const { current, total, date } = attrs;

    const contents = [
      h(
        "div.timeline-replies",
        I18n.t(`topic.timeline.replies_short`, { current, total })
      ),
    ];

    if (date) {
      contents.push(h("div.timeline-ago", timelineDate(date)));
    }

    if (attrs.showDockedButton && !state.dragging) {
      contents.push(attachBackButton(this));
    }
    let result = [
      h("div.timeline-handle"),
      h("div.timeline-scroller-content", contents),
    ];

    if (attrs.fullScreen) {
      result = [result[1], result[0]];
    }

    return result;
  },

  drag(e) {
    this.state.dragging = true;
    this.sendWidgetAction("updatePercentage", e.pageY);
  },

  dragEnd(e) {
    this.state.dragging = false;
    if ($(e.target).is("button")) {
      this.sendWidgetAction("goBack");
    } else {
      this.sendWidgetAction("commit");
    }
  },
});
