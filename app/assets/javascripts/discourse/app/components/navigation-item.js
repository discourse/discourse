import Component from "@ember/component";
import FilterModeMixin from "discourse/mixins/filter-mode";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend(FilterModeMixin, {
  tagName: "li",
  classNameBindings: [
    "active",
    "content.hasIcon:has-icon",
    "content.classNames",
    "isHidden:hidden",
    "content.name",
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

  @discourseComputed("content.count")
  isHidden(count) {
    return (
      !this.active &&
      this.currentUser &&
      this.currentUser.trust_level > 0 &&
      (this.content.get("name") === "new" ||
        this.content.get("name") === "unread") &&
      count < 1
    );
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

    // To reset the "filter" sticky param, at least one query param is needed.
    // If no query param is present, add an empty one to ensure a ? is
    // appended to the URL.
    if (content.currentRouteQueryParams) {
      if (content.currentRouteQueryParams.filter && queryParams.length === 0) {
        queryParams.push("");
      }

      if (content.currentRouteQueryParams.f) {
        queryParams.push(`f=${content.currentRouteQueryParams.f}`);
      }
    }

    if (
      this.siteSettings.desktop_category_page_style ===
      "categories_and_latest_topics_created_date"
    ) {
      queryParams.push("order=created");
    }

    if (queryParams.length) {
      href += `?${queryParams.join("&")}`;
    }
    this.set("hrefLink", href);

    this.set("activeClass", this.active ? "active" : "");
  },
});
