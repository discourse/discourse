import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
import { bufferedRender } from "discourse-common/lib/buffered-render";

export default Component.extend(
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
      const content = this.content;

      let href = content.get("href");
      let queryParams = [];

      // Include the category id if the option is present
      if (content.get("includeCategoryId")) {
        let categoryId = this.get("category.id");
        if (categoryId) {
          queryParams.push(`category_id=${categoryId}`);
        }
      }

      // ensures we keep discovery query params added through plugin api
      if (content.persistedQueryParams) {
        Object.keys(content.persistedQueryParams).forEach(key => {
          const value = content.persistedQueryParams[key];
          queryParams.push(`${key}=${value}`);
        });
      }

      if (queryParams.length) {
        href += `?${queryParams.join("&")}`;
      }

      if (
        !this.active &&
        this.currentUser &&
        this.currentUser.trust_level > 0 &&
        (content.get("name") === "new" || content.get("name") === "unread") &&
        content.get("count") < 1
      ) {
        this.set("hidden", true);
      } else {
        this.set("hidden", false);
      }

      buffer.push(
        `<a href='${href}'` + (this.active ? 'class="active"' : "") + `>`
      );

      if (content.get("hasIcon")) {
        buffer.push("<span class='" + content.get("name") + "'></span>");
      }
      buffer.push(this.get("content.displayName"));
      buffer.push("</a>");
    }
  })
);
