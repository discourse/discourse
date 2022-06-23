import { createWidget } from "discourse/widgets/widget";

export default createWidget("user-status-bubble", {
  tagName: "div.user-status-background",

  html(attrs) {
    return this.attach("emoji", { name: attrs.emoji });
  },
});
