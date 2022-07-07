import GlimmerComponent from "discourse/components/glimmer";
import { bind } from "discourse-common/utils/decorators";
createWidget("timeline-last-read", {
  tagName: "div.timeline-last-read",

  buildAttributes(attrs) {
    const bottom = scrollareaHeight() - LAST_READ_HEIGHT / 2;
    const top = attrs.top > bottom ? bottom : attrs.top;
    return { style: `height: ${LAST_READ_HEIGHT}px; top: ${top}px` };
  },

  html(attrs) {
    const result = [iconNode("minus", { class: "progress" })];
    if (attrs.showButton) {
      result.push(attachBackButton(this));
    }

    return result;
  },
});
