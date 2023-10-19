import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import {
  SCROLLER_HEIGHT,
  timelineDate,
} from "discourse/components/topic-timeline/container";
import I18n from "discourse-i18n";

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
