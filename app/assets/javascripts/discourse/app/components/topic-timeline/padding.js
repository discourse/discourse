import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";
createWidget("timeline-padding", {
  tagName: "div.timeline-padding",
  buildAttributes(attrs) {
    return { style: `height: ${attrs.height}px` };
  },

  click(e) {
    this.sendWidgetAction("updatePercentage", e.pageY);
    this.sendWidgetAction("commit");
  },
});
