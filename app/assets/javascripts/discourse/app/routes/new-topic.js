import { next } from "@ember/runloop";
import { service } from "@ember/service";
import cookie from "discourse/lib/cookie";
import Category from "discourse/models/category";
import DiscourseRoute from "discourse/routes/discourse";

export default class extends DiscourseRoute {
  @service composer;
  @service router;
  @service currentUser;
  @service site;

  async beforeModel(transition) {
    if (this.currentUser) {
      let category;
      if (this.site.lazy_load_categories) {
        if (transition.to.queryParams.category_id) {
          const categories = await Category.asyncFindByIds([
            transition.to.queryParams.category_id,
          ]);
          category = categories[0];
        } else if (transition.to.queryParams.category) {
          category = await Category.asyncFindBySlugPath(
            transition.to.queryParams.category
          );
        }
      } else {
        category = this.parseCategoryFromTransition(transition);
      }

      if (category) {
        // Using URL-based transition to avoid bug with dynamic segments and refreshModel query params
        // https://github.com/emberjs/ember.js/issues/16992
        this.router
          .replaceWith(`/c/${category.id}`)
          .followRedirects()
          .then(() => {
            if (this.currentUser.can_create_topic) {
              this.openComposer({ transition, category });
            }
          });
      } else if (transition.from) {
        // Navigation from another ember route
        transition.abort();
        this.openComposer({ transition });
      } else {
        this.router
          .replaceWith("discovery.latest")
          .followRedirects()
          .then(() => {
            if (this.currentUser.can_create_topic) {
              this.openComposer({ transition });
            }
          });
      }
    } else {
      // User is not logged in
      cookie("destination_url", window.location.href);
      this.router.replaceWith("login");
    }
  }

  openComposer({ transition, category }) {
    next(() => {
      this.composer.openNewTopic({
        title: transition.to.queryParams.title,
        body: transition.to.queryParams.body,
        category,
        tags: transition.to.queryParams.tags,
      });

      this.composer.set("formTemplateInitialValues", transition.to.queryParams);
    });
  }

  parseCategoryFromTransition(transition) {
    let category;

    if (transition.to.queryParams.category_id) {
      const categoryId = transition.to.queryParams.category_id;
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
    }
    return category;
  }

  _getCategory(mainCategory, subCategory, type) {
    let category;
    if (!subCategory) {
      category = this.site.categories.findBy(type, mainCategory.toLowerCase());
    } else {
      const categories = this.site.categories;
      const main = categories.findBy(type, mainCategory.toLowerCase());
      if (main) {
        category = categories.find((item) => {
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
}
