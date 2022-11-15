import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import {
  SCROLLER_HEIGHT,
  timelineDate,
} from "discourse/components/topic-timeline/scroll-area";
import I18n from "I18n";

export default class TopicTimelineScroller extends Component {
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

  // old code from widget
  //@bind
  //drag(e) {
  //this.dragging = true;
  //this.sendWidgetAction("updatePercentage", e.pageY);
  //}

  // old code from widget
  //@bind
  //dragEnd(e) {
  //this.dragging = false;
  //if ($(e.target).is("button")) {
  //this.sendWidgetAction("goBack");
  //} else {
  //this.sendWidgetAction("commit");
  //}
  //}
}
