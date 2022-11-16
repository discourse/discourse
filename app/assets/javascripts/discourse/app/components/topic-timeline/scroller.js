import Component from "@glimmer/component";
import {
  SCROLLER_HEIGHT,
  timelineDate,
} from "discourse/components/topic-timeline/container";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";

export default class TopicTimelineScroller extends Component {
  style = htmlSafe(`height: ${SCROLLER_HEIGHT}px`);

  get repliesShort() {
    const current = this.args.current;
    const total = this.args.total;
    return I18n.t(`topic.timeline.replies_short`, { current, total });
  }

  get timelineAgo() {
    return timelineDate(this.args.date);
  }
}
