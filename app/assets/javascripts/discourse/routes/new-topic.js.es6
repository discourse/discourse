import Category from "discourse/models/category";

export default Discourse.Route.extend({
  beforeModel: function(transition) {
    const self = this;
    if (Discourse.User.current()) {
      let category, category_id;

      if (transition.queryParams.category_id) {
        category_id = transition.queryParams.category_id;
        category = Category.findById(category_id);
      } else if (transition.queryParams.category) {
        const splitCategory = transition.queryParams.category.split("/");
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
          category_id = category.get("id");
        }
      }

      if (Boolean(category)) {
        let route = "discovery.parentCategory";
        let params = { category, slug: category.get("slug") };
        if (category.get("parentCategory")) {
          route = "discovery.category";
          params = {
            category,
            parentSlug: category.get("parentCategory.slug"),
            slug: category.get("slug")
          };
        }

        self.replaceWith(route, params).then(function(e) {
          if (self.controllerFor("navigation/category").get("canCreateTopic")) {
            Ember.run.next(function() {
              e.send(
                "createNewTopicViaParams",
                transition.queryParams.title,
                transition.queryParams.body,
                category_id,
                transition.queryParams.tags
              );
            });
          }
        });
      } else {
        self.replaceWith("discovery.latest").then(function(e) {
          if (self.controllerFor("navigation/default").get("canCreateTopic")) {
            Ember.run.next(function() {
              e.send(
                "createNewTopicViaParams",
                transition.queryParams.title,
                transition.queryParams.body,
                null,
                transition.queryParams.tags
              );
            });
          }
        });
      }
    } else {
      // User is not logged in
      $.cookie("destination_url", window.location.href);
      if (Discourse.showingSignup) {
        // We're showing the sign up modal
        Discourse.showingSignup = false;
      } else {
        self.replaceWith("login");
      }
    }
  },

  _getCategory(mainCategory, subCategory, type) {
    let category;
    if (!subCategory) {
      category = this.site
        .get("categories")
        .findBy(type, mainCategory.toLowerCase());
    } else {
      const categories = this.site.get("categories");
      const main = categories.findBy(type, mainCategory.toLowerCase());
      if (main) {
        category = categories.find(function(item) {
          return (
            item &&
            item.get(type) === subCategory.toLowerCase() &&
            item.get("parent_category_id") === main.id
          );
        });
      }
    }
    return category;
  }
});
