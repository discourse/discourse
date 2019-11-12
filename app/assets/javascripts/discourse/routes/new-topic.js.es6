import { next } from "@ember/runloop";
import DiscourseRoute from "discourse/routes/discourse";
import Category from "discourse/models/category";

export default DiscourseRoute.extend({
  beforeModel(transition) {
    if (this.currentUser) {
      let category, categoryId;

      if (transition.to.queryParams.category_id) {
        categoryId = transition.to.queryParams.category_id;
        category = Category.findById(categoryId);
      } else if (transition.to.queryParams.category) {
        const splitCategory = transition.to.queryParams.category.split("/");

        category = this._getCategory(
          splitCategory[0],
          splitCategory[1],
          "nameLower"
        );

        if (!category) {
          category = this._getCategory(
            splitCategory[0],
            splitCategory[1],
            "slug"
          );
        }

        if (category) {
          categoryId = category.id;
        }
      }

      if (Boolean(category)) {
        let route = "discovery.parentCategory";
        let params = { category, slug: category.slug };
        if (category.parentCategory) {
          route = "discovery.category";
          params = {
            category,
            parentSlug: category.parentCategory.slug,
            slug: category.slug
          };
        }

        this.replaceWith(route, params).then(e => {
          if (this.controllerFor("navigation/category").canCreateTopic) {
            this._sendTransition(e, transition, categoryId);
          }
        });
      } else {
        this.replaceWith("discovery.latest").then(e => {
          if (this.controllerFor("navigation/default").canCreateTopic) {
            this._sendTransition(e, transition);
          }
        });
      }
    } else {
      // User is not logged in
      $.cookie("destination_url", window.location.href);
      this.replaceWith("login");
    }
  },

  _sendTransition(event, transition, categoryId) {
    next(() => {
      event.send(
        "createNewTopicViaParams",
        transition.to.queryParams.title,
        transition.to.queryParams.body,
        categoryId,
        transition.to.queryParams.tags
      );
    });
  },

  _getCategory(mainCategory, subCategory, type) {
    let category;
    if (!subCategory) {
      category = this.site.categories.findBy(type, mainCategory.toLowerCase());
    } else {
      const categories = this.site.categories;
      const main = categories.findBy(type, mainCategory.toLowerCase());
      if (main) {
        category = categories.find(item => {
          return (
            item &&
            item[type] === subCategory.toLowerCase() &&
            item.parent_category_id === main.id
          );
        });
      }
    }

    return category;
  }
});
