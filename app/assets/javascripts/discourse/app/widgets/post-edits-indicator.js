import { historyHeat } from "discourse/components/post/meta-data/edits-indicator";
import { longDate } from "discourse/lib/formatter";
import { createWidget } from "discourse/widgets/widget";
import { i18n } from "discourse-i18n";

// glimmer-post-stream: has glimmer version
export default createWidget("post-edits-indicator", {
  tagName: "div.post-info.edits",

  html(attrs) {
    let icon = "pencil";
    const updatedAt = new Date(attrs.updated_at);
    let className = historyHeat(this.siteSettings, updatedAt);
    const date = longDate(updatedAt);
    let title;

    if (attrs.wiki) {
      icon = "far-pen-to-square";
      className = `${className || ""} wiki`.trim();

      if (attrs.version > 1) {
        title = i18n("post.wiki_last_edited_on", { dateTime: date });
      } else {
        title = i18n("post.wiki.about");
      }
    } else {
      title = i18n("post.last_edited_on", { dateTime: date });
    }

    return this.attach("flat-button", {
      icon,
      translatedTitle: title,
      className,
      action: "onPostEditsIndicatorClick",
      translatedAriaLabel: i18n("post.edit_history"),
      translatedLabel: attrs.version > 1 ? attrs.version - 1 : "",
    });
  },

  onPostEditsIndicatorClick() {
    if (this.attrs.wiki && this.attrs.version === 1) {
      this.sendWidgetAction("editPost");
    } else if (this.attrs.canViewEditHistory) {
      this.sendWidgetAction("showHistory");
    }
  },
});
