import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import { longDate } from "discourse/lib/formatter";
import { h } from "virtual-dom";

function mult(val) {
  return 60 * 50 * 1000 * val;
}

export function historyHeat(siteSettings, updatedAt) {
  if (!updatedAt) {
    return;
  }

  // Show heat on age
  const rightNow = new Date().getTime();
  const updatedAtTime = updatedAt.getTime();

  if (updatedAtTime > rightNow - mult(siteSettings.history_hours_low)) {
    return "heatmap-high";
  }

  if (updatedAtTime > rightNow - mult(siteSettings.history_hours_medium)) {
    return "heatmap-med";
  }

  if (updatedAtTime > rightNow - mult(siteSettings.history_hours_high)) {
    return "heatmap-low";
  }
}

export default createWidget("post-edits-indicator", {
  tagName: "div.post-info.edits",

  html(attrs) {
    let icon = "pencil-alt";
    const updatedAt = new Date(attrs.updated_at);
    let className = historyHeat(this.siteSettings, updatedAt);
    const date = longDate(updatedAt);
    let title;

    if (attrs.wiki) {
      icon = "far-edit";
      className = `${className || ""} wiki`.trim();

      if (attrs.version > 1) {
        title = `${I18n.t("post.last_edited_on")} ${date}`;
      } else {
        title = I18n.t("post.wiki.about");
      }
    } else {
      title = `${I18n.t("post.last_edited_on")} ${date}`;
    }

    const contents = [
      attrs.version > 1 ? attrs.version - 1 : "",
      " ",
      iconNode(icon)
    ];

    return h(
      "a",
      {
        className,
        attributes: { title, href: "#" }
      },
      contents
    );
  },

  click(e) {
    e.preventDefault();
    if (this.attrs.wiki && this.attrs.version === 1) {
      this.sendWidgetAction("editPost");
    } else if (this.attrs.canViewEditHistory) {
      this.sendWidgetAction("showHistory");
    }
  }
});
