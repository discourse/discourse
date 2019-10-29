import EmberObject from "@ember/object";
import DiscourseRoute from "discourse/routes/discourse";
import showModal from "discourse/lib/show-modal";
import OpenComposer from "discourse/mixins/open-composer";
import CategoryList from "discourse/models/category-list";
import { defaultHomepage } from "discourse/lib/utilities";
import TopicList from "discourse/models/topic-list";
import { ajax } from "discourse/lib/ajax";
import PreloadStore from "preload-store";
import { searchPriorities } from "discourse/components/concerns/category-search-priorities";

const DiscoveryCategoriesRoute = DiscourseRoute.extend(OpenComposer, {
  renderTemplate() {
    this.render("navigation/categories", { outlet: "navigation-bar" });
    this.render("discovery/categories", { outlet: "list-container" });
  },

  findCategories() {
    let style =
      !this.site.mobileView && this.siteSettings.desktop_category_page_style;

    let parentCategory = this.get("model.parentCategory");
    if (parentCategory) {
      return CategoryList.listForParent(this.store, parentCategory);
    } else if (style === "categories_and_latest_topics") {
      return this._findCategoriesAndTopics("latest");
    } else if (style === "categories_and_top_topics") {
      return this._findCategoriesAndTopics("top");
    }

    return CategoryList.list(this.store);
  },

  model() {
    return this.findCategories().then(model => {
      const tracking = this.topicTrackingState;
      if (tracking) {
        tracking.sync(model, "categories");
        tracking.trackIncoming("categories");
      }
      return model;
    });
  },

  _findCategoriesAndTopics(filter) {
    return Ember.RSVP.hash({
      wrappedCategoriesList: PreloadStore.getAndRemove("categories_list"),
      topicsList: PreloadStore.getAndRemove(`topic_list_${filter}`)
    }).then(hash => {
      let { wrappedCategoriesList, topicsList } = hash;
      let categoriesList =
        wrappedCategoriesList && wrappedCategoriesList.category_list;

      if (categoriesList && topicsList) {
        return EmberObject.create({
          categories: CategoryList.categoriesFrom(
            this.store,
            wrappedCategoriesList
          ),
          topics: TopicList.topicsFrom(this.store, topicsList),
          can_create_category: categoriesList.can_create_category,
          can_create_topic: categoriesList.can_create_topic,
          draft_key: categoriesList.draft_key,
          draft: categoriesList.draft,
          draft_sequence: categoriesList.draft_sequence
        });
      }
      // Otherwise, return the ajax result
      return ajax(`/categories_and_${filter}`).then(result => {
        return EmberObject.create({
          categories: CategoryList.categoriesFrom(this.store, result),
          topics: TopicList.topicsFrom(this.store, result),
          can_create_category: result.category_list.can_create_category,
          can_create_topic: result.category_list.can_create_topic,
          draft_key: result.category_list.draft_key,
          draft: result.category_list.draft,
          draft_sequence: result.category_list.draft_sequence
        });
      });
    });
  },

  titleToken() {
    if (defaultHomepage() === "categories") {
      return;
    }
    return I18n.t("filters.categories.title");
  },

  setupController(controller, model) {
    controller.set("model", model);

    this.controllerFor("navigation/categories").setProperties({
      showCategoryAdmin: model.get("can_create_category"),
      canCreateTopic: model.get("can_create_topic")
    });
  },

  actions: {
    triggerRefresh() {
      this.refresh();
    },

    createCategory() {
      const groups = this.site.groups,
        everyoneName = groups.findBy("id", 0).name;

      const model = this.store.createRecord("category", {
        color: "0088CC",
        text_color: "FFFFFF",
        group_permissions: [{ group_name: everyoneName, permission_type: 1 }],
        available_groups: groups.map(g => g.name),
        allow_badges: true,
        topic_featured_link_allowed: true,
        custom_fields: {},
        search_priority: searchPriorities.normal
      });

      showModal("edit-category", { model });
      this.controllerFor("edit-category").set("selectedTab", "general");
    },

    reorderCategories() {
      showModal("reorderCategories");
    },

    createTopic() {
      const model = this.controllerFor("discovery/categories").get("model");
      if (model.draft) {
        this.openTopicDraft(model);
      } else {
        this.openComposer(this.controllerFor("discovery/categories"));
      }
    },

    didTransition() {
      Ember.run.next(() =>
        this.controllerFor("application").set("showFooter", true)
      );
      return true;
    }
  }
});

export default DiscoveryCategoriesRoute;
