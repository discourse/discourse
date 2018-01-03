import showModal from "discourse/lib/show-modal";
import OpenComposer from "discourse/mixins/open-composer";
import CategoryList from "discourse/models/category-list";
import { defaultHomepage } from 'discourse/lib/utilities';
import TopicList from "discourse/models/topic-list";
import { ajax } from "discourse/lib/ajax";
import PreloadStore from "preload-store";

const DiscoveryCategoriesRoute = Discourse.Route.extend(OpenComposer, {
  renderTemplate() {
    this.render("navigation/categories", { outlet: "navigation-bar" });
    this.render("discovery/categories", { outlet: "list-container" });
  },

  model() {
    const style = !this.site.mobileView && this.siteSettings.desktop_category_page_style;
    const parentCategory = this.get("model.parentCategory");

    let promise;
    if (parentCategory) {
      promise = CategoryList.listForParent(this.store, parentCategory);
    } else if (style === "categories_and_latest_topics") {
      promise = this._loadCategoriesAndLatestTopics();
    } else {
      promise = CategoryList.list(this.store);
    }

    return promise.then(model => {
      const tracking = this.topicTrackingState;
      if (tracking) {
        tracking.sync(model, "categories");
        tracking.trackIncoming("categories");
      }
      return model;
    });
  },

  _loadCategoriesAndLatestTopics() {
    const wrappedCategoriesList = PreloadStore.getAndRemove("categories_list");
    const topicListLatest = PreloadStore.getAndRemove("topic_list_latest");
    const categoriesList = wrappedCategoriesList && wrappedCategoriesList.category_list;
    if (categoriesList && topicListLatest) {
      return new Ember.RSVP.Promise(resolve => {
        const result = Ember.Object.create({
          categories: CategoryList.categoriesFrom(this.store, wrappedCategoriesList),
          topics: TopicList.topicsFrom(this.store, topicListLatest),
          can_create_category: categoriesList.can_create_category,
          can_create_topic: categoriesList.can_create_topic,
          draft_key: categoriesList.draft_key,
          draft: categoriesList.draft,
          draft_sequence: categoriesList.draft_sequence
        });

        resolve(result);
      });
    } else {
      return ajax("/categories_and_latest").then(result => {
        return Ember.Object.create({
          categories: CategoryList.categoriesFrom(this.store, result),
          topics: TopicList.topicsFrom(this.store, result),
          can_create_category: result.category_list.can_create_category,
          can_create_topic: result.category_list.can_create_topic,
          draft_key: result.category_list.draft_key,
          draft: result.category_list.draft,
          draft_sequence: result.category_list.draft_sequence
        });
      });
    }
  },

  titleToken() {
    if (defaultHomepage() === "categories") { return; }
    return I18n.t("filters.categories.title");
  },

  setupController(controller, model) {
    controller.set("model", model);

    this.controllerFor("navigation/categories").setProperties({
      showCategoryAdmin: model.get("can_create_category"),
      canCreateTopic: model.get("can_create_topic"),
    });

    this.openTopicDraft(model);
  },

  actions: {

    refresh() {
      const controller = this.controllerFor("discovery/categories");
      const discController = this.controllerFor("discovery");

      // Don't refresh if we're still loading
      if (!discController || discController.get("loading")) { return; }

      // If we `send('loading')` here, due to returning true it bubbles up to the
      // router and ember throws an error due to missing `handlerInfos`.
      // Lesson learned: Don't call `loading` yourself.
      discController.set("loading", true);

      this.model().then(model => {
        this.setupController(controller, model);
        controller.send("loadingComplete");
      });
    },

    createCategory() {
      const groups = this.site.groups,
            everyoneName = groups.findBy("id", 0).name;

      const model = this.store.createRecord('category', {
        color: "AB9364", text_color: "FFFFFF", group_permissions: [{group_name: everyoneName, permission_type: 1}],
        available_groups: groups.map(g => g.name),
        allow_badges: true,
        topic_featured_link_allowed: true
      });

      showModal("edit-category", { model });
      this.controllerFor("edit-category").set("selectedTab", "general");
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
