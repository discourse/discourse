import GlimmerComponent from "discourse/components/glimmer";
import { scrollareaHeight } from "discourse/components/topic-timeline/scroll-area";

const LAST_READ_HEIGHT = 20;

export default class TopicTimelineLastRead extends GlimmerComponent {
  style = `height: ${LAST_READ_HEIGHT}px; top: ${this.top}px`;

  get top() {
    const bottom = scrollareaHeight() - LAST_READ_HEIGHT / 2;
    return this.args.top > bottom ? bottom : this.args.top;
  }
}
