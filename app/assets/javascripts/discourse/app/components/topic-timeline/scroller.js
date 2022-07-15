import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import { SCROLLER_HEIGHT } from "discourse/components/topic-timeline/scroll-area";
import { timelineDate } from "discourse/components/topic-timeline/date";

export default class TopicTimelineScroller extends GlimmerComponent {
  @tracked dragging = false;

  style = `height: ${SCROLLER_HEIGHT}px`;

  get repliesShort() {
    const current = this.args.current;
    const total = this.args.total;
    return I18n.t(`topic.timeline.replies_short`, { current, total });
  }

  get timelineAgo() {
    return timelineDate(this.args.date);
  }

  @bind
  drag(e) {
    this.dragging = true;
    // update to send value to parent
    this.sendWidgetAction("updatePercentage", e.pageY);
  }

  @bind
  dragEnd(e) {
    this.dragging = false;
    if ($(e.target).is("button")) {
      this.sendWidgetAction("goBack");
    } else {
      this.sendWidgetAction("commit");
    }
  }
}
