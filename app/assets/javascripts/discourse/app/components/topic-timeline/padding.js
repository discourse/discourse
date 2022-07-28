import GlimmerComponent from "discourse/components/glimmer";
//import { action } from "@ember/object";

export default class TopicTimelinePadding extends GlimmerComponent {
  style = `height: ${this.args.height}px`;

  // old code from widget
  //click(e) {
  //this.sendWidgetAction("updatePercentage", e.pageY);
  //this.sendWidgetAction("commit");
  //}
}
