import { createWidget } from "discourse/widgets/widget";

export default createWidget("user-status-bubble", {
  tagName: "div.user-status-background",
  fallbackEmoji: "heart",

  html(attrs) {
    const emoji = attrs.emoji ?? this.fallbackEmoji;
    return this.attach("emoji", { name: emoji });
  },
});
