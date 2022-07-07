import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";
createWidget("timeline-controls", {
  tagName: "div.timeline-controls",

  html(attrs) {
    const controls = [];
    const { fullScreen, currentUser, topic } = attrs;

    if (!fullScreen && currentUser) {
      controls.push(
        this.attach("topic-admin-menu-button", {
          topic,
          addKeyboardTargetClass: true,
        })
      );
    }

    return controls;
  },
});
