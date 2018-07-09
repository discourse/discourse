import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { number } from "discourse/lib/formatter";

createWidget("hamburger-category", {
  tagName: "li.category-link",

  html(c) {
    if (c.parent_category_id) {
      this.tagName += ".subcategory";
    }

    this.tagName += ".category-" + Discourse.Category.slugFor(c, "-");

    const results = [
      this.attach("category-link", { category: c, allowUncategorized: true })
    ];

    const unreadTotal =
      parseInt(c.get("unreadTopics"), 10) + parseInt(c.get("newTopics"), 10);
    if (unreadTotal) {
      results.push(
        h(
          "a.badge.badge-notification",
          {
            attributes: { href: c.get("url") }
          },
          number(unreadTotal)
        )
      );
    }

    if (!this.currentUser) {
      let count = c.get("topic_count");

      if (c.get("show_subcategory_list")) {
        const subcats = c.get("subcategories");
        if (subcats) {
          subcats.forEach(s => {
            count += s.get("topic_count");
          });
        }
      }

      results.push(h("b.topics-count", number(count)));
    }

    return results;
  }
});

export default createWidget("hamburger-categories", {
  tagName: "ul.category-links.clearfix",

  html(attrs) {
    const href = Discourse.getURL("/categories");
    const result = [
      h(
        "li.heading",
        h(
          "a.d-link.categories-link",
          { attributes: { href } },
          I18n.t("filters.categories.title")
        )
      )
    ];

    const categories = attrs.categories;
    if (categories.length === 0) {
      return;
    }
    return result.concat(
      categories.map(c => this.attach("hamburger-category", c))
    );
  }
});
