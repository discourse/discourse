import Component from "@ember/component";
import { bufferedRender } from "discourse-common/lib/buffered-render";

// Creates a link
function link(buffer, prop, url, cssClass, i18nKey, text) {
  if (!prop) {
    return;
  }
  const title = I18n.t("topic." + i18nKey, { count: prop });
  buffer.push(
    `<a href="${url}" class="badge ${cssClass} badge-notification" title="${title}">${text ||
      prop}</a>\n`
  );
}

export default Component.extend(
  bufferedRender({
    tagName: "span",
    classNameBindings: [":topic-post-badges"],
    rerenderTriggers: ["url", "unread", "newPosts", "unseen"],

    buildBuffer(buffer) {
      const newDotText =
        this.currentUser && this.currentUser.trust_level > 0
          ? " "
          : I18n.t("filters.new.lower_title");
      const url = this.url;
      link(buffer, this.unread, url, "unread", "unread_posts");
      link(buffer, this.newPosts, url, "new-posts", "new_posts");
      link(buffer, this.unseen, url, "new-topic", "new", newDotText);
    }
  })
);
