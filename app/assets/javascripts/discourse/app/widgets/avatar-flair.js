import { createWidget } from "discourse/widgets/widget";
import { iconNode, convertIconClass } from "discourse-common/lib/icon-library";
import { escapeExpression } from "discourse/lib/utilities";

createWidget("avatar-flair", {
  tagName: "div.avatar-flair",

  isIcon(attrs) {
    return (
      attrs.primary_group_flair_url &&
      !attrs.primary_group_flair_url.includes("/")
    );
  },

  title(attrs) {
    return attrs.primary_group_name;
  },

  buildClasses(attrs) {
    let defaultClass = `avatar-flair-${attrs.primary_group_name} ${
      attrs.primary_group_flair_bg_color ? "rounded" : ""
    }`;

    if (!this.isIcon(attrs)) {
      defaultClass += " avatar-flair-image";
    }

    return defaultClass;
  },

  buildAttributes(attrs) {
    var style = "";
    if (!this.isIcon(attrs)) {
      style +=
        "background-image: url(" +
        escapeExpression(attrs.primary_group_flair_url) +
        "); ";
    }
    if (attrs.primary_group_flair_bg_color) {
      style +=
        "background-color: #" +
        escapeExpression(attrs.primary_group_flair_bg_color) +
        "; ";
    }
    if (attrs.primary_group_flair_color) {
      style +=
        "color: #" + escapeExpression(attrs.primary_group_flair_color) + "; ";
    }
    return { style: style };
  },

  html(attrs) {
    if (this.isIcon(attrs)) {
      const icon = convertIconClass(attrs.primary_group_flair_url);
      return [iconNode(icon)];
    } else {
      return [];
    }
  }
});
