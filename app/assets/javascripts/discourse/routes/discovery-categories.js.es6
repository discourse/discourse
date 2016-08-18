import showModal from "discourse/lib/show-modal";
import OpenComposer from "discourse/mixins/open-composer";
import CategoryList from "discourse/models/category-list";
import { defaultHomepage } from 'discourse/lib/utilities';
import TopicList from "discourse/models/topic-list";

const DiscoveryCategoriesRoute = Discourse.Route.extend(OpenComposer, {
  renderTemplate() {
    this.render("navigation/categories", { outlet: "navigation-bar" });
    this.render("discovery/categories", { outlet: "list-container" });
  },

  beforeModel() {
    this.controllerFor("navigation/categories").set("filterMode", "categories");
  },

  model() {
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
    if (defaultHomepage() === "categories") { return; }
    return I18n.t("filters.categories.title");
  },

  setupController(controller, model) {
    model.set("loadingTopics", true);

    TopicList.find("latest")
             .then(result => model.set("topicList", result))
             .finally(() => model.set("loadingTopics", false));

    controller.set("model", model);

    this.controllerFor("navigation/categories").setProperties({
      canCreateCategory: model.get("can_create_category"),
      canCreateTopic: model.get("can_create_topic"),
    });

    this.openTopicDraft(model);
  },

  actions: {

    refresh() {
      const controller = this.controllerFor("discovery/categories");

      // Don't refresh if we're still loading
      if (!controller || controller.get("loading")) { return; }

      // If we `send('loading')` here, due to returning true it bubbles up to the
      // router and ember throws an error due to missing `handlerInfos`.
      // Lesson learned: Don't call `loading` yourself.
      controller.set("loading", true);

      const parentCategory = this.get("model.parentCategory");
      const promise = parentCategory ? CategoryList.listForParent(this.store, parentCategory) :
                                       CategoryList.list(this.store);

      promise.then(list => {
        this.setupController(controller, list);
        controller.send("loadingComplete");
      });
    },

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
