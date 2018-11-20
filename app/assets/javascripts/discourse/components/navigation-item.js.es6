import computed from "ember-addons/ember-computed-decorators";
import { bufferedRender } from "discourse-common/lib/buffered-render";

export default Ember.Component.extend(
  bufferedRender({
    tagName: "li",
    classNameBindings: [
      "active",
      "content.hasIcon:has-icon",
      "content.classNames",
      "hidden"
    ],
    attributeBindings: ["content.title:title"],
    hidden: false,
    rerenderTriggers: ["content.count"],

    @computed("content.filterMode", "filterMode")
    active(contentFilterMode, filterMode) {
      return (
        contentFilterMode === filterMode ||
        filterMode.indexOf(contentFilterMode) === 0
      );
    },

    buildBuffer(buffer) {
      const content = this.get("content");

      let href = content.get("href");

      // Include the category id if the option is present
      if (content.get("includeCategoryId")) {
        let categoryId = this.get("category.id");
        if (categoryId) {
          href += `?category_id=${categoryId}`;
        }
      }

      if (
        !this.get("active") &&
        this.currentUser &&
        this.currentUser.trust_level > 0 &&
        (content.get("name") === "new" || content.get("name") === "unread") &&
        content.get("count") < 1
      ) {
        this.set("hidden", true);
      } else {
        this.set("hidden", false);
      }

      buffer.push(`<a href='${href}'>`);
      if (content.get("hasIcon")) {
        buffer.push("<span class='" + content.get("name") + "'></span>");
      }
      buffer.push(this.get("content.displayName"));
      buffer.push("</a>");
    }
  })
);
