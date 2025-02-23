import { convertIconClass, iconNode } from "discourse/lib/icon-library";
import { escapeExpression } from "discourse/lib/utilities";
import { createWidget } from "discourse/widgets/widget";

createWidget("avatar-flair", {
  tagName: "div.avatar-flair",

  isIcon(attrs) {
    return attrs.flair_url && !attrs.flair_url.includes("/");
  },

  title(attrs) {
    return attrs.flair_name;
  },

  buildClasses(attrs) {
    let defaultClass = `avatar-flair-${attrs.flair_name} ${
      attrs.flair_bg_color ? "rounded" : ""
    }`;

    if (!this.isIcon(attrs)) {
      defaultClass += " avatar-flair-image";
    }

    return defaultClass;
  },

  buildAttributes(attrs) {
    let style = "";
    if (!this.isIcon(attrs)) {
      style +=
        "background-image: url(" + escapeExpression(attrs.flair_url) + "); ";
    }
    if (attrs.flair_bg_color) {
      style +=
        "background-color: #" + escapeExpression(attrs.flair_bg_color) + "; ";
    }
    if (attrs.flair_color) {
      style += "color: #" + escapeExpression(attrs.flair_color) + "; ";
    }
    return { style };
  },

  html(attrs) {
    if (this.isIcon(attrs)) {
      const icon = convertIconClass(attrs.flair_url);
      return [iconNode(icon)];
    } else {
      return [];
    }
  },
});
