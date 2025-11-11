import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import DiscourseRoute from "discourse/routes/discourse";

export default class extends DiscourseRoute {
  @service composer;
  @service currentUser;
  @service router;
  @service site;

  async beforeModel(transition) {
    if (!this.currentUser) {
      transition.send("showLogin");
      return;
    }

    const { queryParams: params } = transition.to;
    const category = await this.#loadCategoryFromTransition(params);

    if (category) {
      // Using URL-based transition to avoid bug with dynamic segments and refreshModel query params
      // https://github.com/emberjs/ember.js/issues/16992
      this.router
        .replaceWith(`/c/${category.id}`)
        .followRedirects()
        .then(() => {
          if (this.currentUser.can_create_topic) {
            this.#openComposer(params, category);
          }
        });
      return;
    }

    // When navigating from another ember route
    if (transition.from) {
      transition.abort();
      this.#openComposer(params);
      return;
    }

    // When landing on the route from a full page load
    this.router
      .replaceWith(`discovery.${defaultHomepage()}`)
      .followRedirects()
      .then(() => {
        if (this.currentUser.can_create_topic) {
          this.#openComposer(params);
        }
      });
  }

  #openComposer(params, category) {
    const { title, body, tags } = params;

    next(() => {
      this.composer.openNewTopic({ title, body, category, tags });
      this.composer.set("formTemplateInitialValues", params);
    });
  }

  async #loadCategoryFromTransition(params) {
    let category = null;

    if (this.site.lazy_load_categories) {
      if (params.category_id) {
        category = await Category.asyncFindById(params.category_id);
      } else if (params.category) {
        category = await Category.asyncFindBySlugPath(params.category);
      }
    } else {
      if (params.category_id) {
        category = Category.findById(params.category_id);
      } else if (params.category) {
        // TODO: does this work with more than 2 levels of categories?
        const [main, sub] = params.category.split("/");
        category = this.#getCategory(main, sub, "nameLower");
        category ||= this.#getCategory(main, sub, "slug");
      }
    }

    return category;
  }

  #getCategory(main, sub, type) {
    let category = null;

    if (!sub) {
      category = this.site.categories.find(
        (c) => c[type] === main.toLowerCase()
      );
    } else {
      const { categories } = this.site;
      const parent = categories.find((c) => c[type] === main.toLowerCase());

      if (parent) {
        category = categories.find((item) => {
          return (
            item &&
            item[type] === sub.toLowerCase() &&
            item.parent_category_id === parent.id
          );
        });
      }
    }

    return category;
  }
}
