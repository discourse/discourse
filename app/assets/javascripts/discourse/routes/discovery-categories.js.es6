import showModal from "discourse/lib/show-modal";
import OpenComposer from "discourse/mixins/open-composer";
import CategoryList from "discourse/models/category-list";

const DiscoveryCategoriesRoute = Discourse.Route.extend(OpenComposer, {
  renderTemplate() {
    this.render("navigation/categories", { outlet: "navigation-bar" });
    this.render("discovery/categories", { outlet: "list-container" });
  },

  beforeModel() {
    this.controllerFor("navigation/categories").set("filterMode", "categories");
  },

  model() {
    // TODO: Remove this and ensure server side does not supply `topic_list`
    // if default page is categories
    PreloadStore.remove("topic_list");

    return CategoryList.list(this.store, 'categories').then(list => {
      const tracking = this.topicTrackingState;
      if (tracking) {
        tracking.sync(list, "categories");
        tracking.trackIncoming("categories");
      }
      return list;
    });
  },

  titleToken() {
    if (Discourse.Utilities.defaultHomepage() === "categories") { return; }
    return I18n.t("filters.categories.title");
  },

  setupController(controller, model) {
    controller.set("model", model);

    this.controllerFor("navigation/categories").setProperties({
      canCreateCategory: model.get("can_create_category"),
      canCreateTopic: model.get("can_create_topic"),
    });

    this.openTopicDraft(model);
  },

  actions: {
    createCategory() {
      const groups = this.site.groups,
            everyoneName = groups.findBy("id", 0).name;

      const model = this.store.createRecord('category', {
        color: "AB9364", text_color: "FFFFFF", group_permissions: [{group_name: everyoneName, permission_type: 1}],
        available_groups: groups.map(g => g.name),
        allow_badges: true
      });

      showModal("editCategory", { model });
      this.controllerFor("editCategory").set("selectedTab", "general");
    },

    reorderCategories() {
      showModal("reorderCategories");
    },

    createTopic() {
      this.openComposer(this.controllerFor("discovery/categories"));
    },

    didTransition() {
      Ember.run.next(() => this.controllerFor("application").set("showFooter", true));
      return true;
    }
  }
});

export default DiscoveryCategoriesRoute;
