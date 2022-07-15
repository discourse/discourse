import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";

export default class TopicTimelinePadding extends GlimmerComponent {
  style = `height: ${this.args.height}px`;

  click(e) {
    this.sendWidgetAction("updatePercentage", e.pageY);
    this.sendWidgetAction("commit");
  }
}
