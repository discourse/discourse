import CategoryList from "discourse/models/category-list";
import DiscourseRoute from "discourse/routes/discourse";
import EmberObject from "@ember/object";
import I18n from "I18n";
import OpenComposer from "discourse/mixins/open-composer";
import PreloadStore from "discourse/lib/preload-store";
import Site from "discourse/models/site";
import TopicList from "discourse/models/topic-list";
import { ajax } from "discourse/lib/ajax";
import { defaultHomepage } from "discourse/lib/utilities";
import { hash } from "rsvp";
import { next } from "@ember/runloop";
import showModal from "discourse/lib/show-modal";

const DiscoveryCategoriesRoute = DiscourseRoute.extend(OpenComposer, {
  renderTemplate() {
    this.render("navigation/categories", { outlet: "navigation-bar" });
    this.render("discovery/categories", { outlet: "list-container" });
  },

  findCategories() {
    let style =
      !this.site.mobileView && this.siteSettings.desktop_category_page_style;

    if (style === "categories_and_latest_topics") {
      return this._findCategoriesAndTopics("latest");
    } else if (style === "categories_and_top_topics") {
      return this._findCategoriesAndTopics("top");
    }

    return CategoryList.list(this.store);
  },

  model() {
    return this.findCategories().then((model) => {
      const tracking = this.topicTrackingState;
      if (tracking) {
        tracking.sync(model, "categories");
        tracking.trackIncoming("categories");
      }
      return model;
    });
  },

  _findCategoriesAndTopics(filter) {
    return hash({
      wrappedCategoriesList: PreloadStore.getAndRemove("categories_list"),
      topicsList: PreloadStore.getAndRemove(`topic_list_${filter}`),
    }).then((response) => {
      let { wrappedCategoriesList, topicsList } = response;
      let categoriesList =
        wrappedCategoriesList && wrappedCategoriesList.category_list;

      if (categoriesList && topicsList) {
        if (topicsList.topic_list && topicsList.topic_list.top_tags) {
          Site.currentProp("top_tags", topicsList.topic_list.top_tags);
        }

        return EmberObject.create({
          categories: CategoryList.categoriesFrom(
            this.store,
            wrappedCategoriesList
          ),
          topics: TopicList.topicsFrom(this.store, topicsList),
          can_create_category: categoriesList.can_create_category,
          can_create_topic: categoriesList.can_create_topic,
        });
      }
      // Otherwise, return the ajax result
      return ajax(`/categories_and_${filter}`).then((result) => {
        if (result.topic_list && result.topic_list.top_tags) {
          Site.currentProp("top_tags", result.topic_list.top_tags);
        }

        return EmberObject.create({
          categories: CategoryList.categoriesFrom(this.store, result),
          topics: TopicList.topicsFrom(this.store, result),
          can_create_category: result.category_list.can_create_category,
          can_create_topic: result.category_list.can_create_topic,
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
      canCreateTopic: model.get("can_create_topic"),
    });
  },

  actions: {
    triggerRefresh() {
      this.refresh();
    },

    createCategory() {
      this.transitionTo("newCategory");
    },

    reorderCategories() {
      showModal("reorderCategories");
    },

    createTopic() {
      if (this.get("currentUser.has_topic_draft")) {
        this.openTopicDraft();
      } else {
        this.openComposer(this.controllerFor("discovery/categories"));
      }
    },

    didTransition() {
      next(() => this.controllerFor("application").set("showFooter", true));
      return true;
    },
  },
});

export default DiscoveryCategoriesRoute;
