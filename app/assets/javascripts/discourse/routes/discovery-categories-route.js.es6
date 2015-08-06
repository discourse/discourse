import showModal from "discourse/lib/show-modal";
import OpenComposer from "discourse/mixins/open-composer";

Discourse.DiscoveryCategoriesRoute = Discourse.Route.extend(OpenComposer, {
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

    return Discourse.CategoryList.list("categories").then(function(list) {
      const tracking = Discourse.TopicTrackingState.current();
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

    // Only show either the Create Category or Create Topic button
    this.controllerFor("navigation/categories").set("canCreateCategory", model.get("can_create_category"));
    this.controllerFor("navigation/categories").set("canCreateTopic", model.get("can_create_topic") && !model.get("can_create_category"));

    this.openTopicDraft(model);
  },

  actions: {
    createCategory() {
      const groups = this.site.groups,
            everyoneName = groups.findBy("id", 0).name;

      const model = Discourse.Category.create({
        color: "AB9364", text_color: "FFFFFF", group_permissions: [{group_name: everyoneName, permission_type: 1}],
        available_groups: groups.map(g => g.name),
        allow_badges: true
      });

      showModal("editCategory", { model });
      this.controllerFor("editCategory").set("selectedTab", "general");
    },

    createTopic() {
      this.openComposer(this.controllerFor("discovery/categories"));
    },

    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});

export default Discourse.DiscoveryCategoriesRoute;
