import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import FilterModeMixin from "discourse/mixins/filter-mode";

export default Component.extend(FilterModeMixin, {
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
  activeClass: "",
  hrefLink: null,

  @discourseComputed("content.filterType", "filterType", "content.active")
  active(contentFilterType, filterType, active) {
    if (active !== undefined) {
      return active;
    }
    return contentFilterType === filterType;
  },

  didReceiveAttrs() {
    this._super(...arguments);
    const content = this.content;

    let href = content.get("href");
    let queryParams = [];

    // Include the category id if the option is present
    if (content.get("includeCategoryId")) {
      let categoryId = this.get("content.category.id");
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
    this.set("hrefLink", href);

    this.set("activeClass", this.active ? "active" : "");

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
  }
});
