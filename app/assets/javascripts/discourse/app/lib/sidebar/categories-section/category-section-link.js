import { htmlSafe } from "@ember/template";

import { categoryBadgeHTML } from "discourse/helpers/category-link";
import Category from "discourse/models/category";

export default class CategorySectionLink {
  constructor({ category }) {
    this.category = category;
  }

  get name() {
    return this.category.slug;
  }

  get route() {
    return "discovery.latestCategory";
  }

  get model() {
    return `${Category.slugFor(this.category)}/${this.category.id}`;
  }

  get currentWhen() {
    return "discovery.unreadCategory discovery.topCategory discovery.newCategory discovery.latestCategory";
  }

  get title() {
    return this.category.description_excerpt;
  }

  get text() {
    return htmlSafe(categoryBadgeHTML(this.category, { link: false }));
  }
}
