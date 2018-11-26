import { createWidget } from "discourse/widgets/widget";
import { iconNode, convertIconClass } from "discourse-common/lib/icon-library";

createWidget("avatar-flair", {
  tagName: "div.avatar-flair",

  isIcon(attrs) {
    return (
      attrs.primary_group_flair_url &&
      attrs.primary_group_flair_url.includes("fa-")
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
        Handlebars.Utils.escapeExpression(attrs.primary_group_flair_url) +
        "); ";
    }
    if (attrs.primary_group_flair_bg_color) {
      style +=
        "background-color: #" +
        Handlebars.Utils.escapeExpression(attrs.primary_group_flair_bg_color) +
        "; ";
    }
    if (attrs.primary_group_flair_color) {
      style +=
        "color: #" +
        Handlebars.Utils.escapeExpression(attrs.primary_group_flair_color) +
        "; ";
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
