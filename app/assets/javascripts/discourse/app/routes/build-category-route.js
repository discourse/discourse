import { Promise, all } from "rsvp";
import {
  changeSort,
  queryParams,
  resetParams,
} from "discourse/controllers/discovery-sortable";
import {
  filterQueryParams,
  findTopicList,
} from "discourse/routes/build-topic-route";
import Category from "discourse/models/category";
import CategoryList from "discourse/models/category-list";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import PermissionType from "discourse/models/permission-type";
import TopicList from "discourse/models/topic-list";
import { action } from "@ember/object";
import PreloadStore from "discourse/lib/preload-store";
import { inject as service } from "@ember/service";

// A helper function to create a category route with parameters
export default (filterArg, params) => {
  return DiscourseRoute.extend({
    queryParams,
    composer: service(),
    templateName: "discovery/category",

    model(modelParams) {
      const category = Category.findBySlugPathWithID(
        modelParams.category_slug_path_with_id
      );

      if (!category) {
        const parts = modelParams.category_slug_path_with_id.split("/");
        if (parts.length > 0 && parts[parts.length - 1].match(/^\d+$/)) {
          parts.pop();
        }

        return Category.reloadBySlugPath(parts.join("/")).then((result) => {
          const record = this.store.createRecord("category", result.category);
          record.setupGroupsAndPermissions();
          this.site.updateCategory(record);
          return { category: record, modelParams };
        });
      }

      if (category) {
        return { category, modelParams };
      }
    },

    afterModel(model, transition) {
      if (!model) {
        this.replaceWith("/404");
        return;
      }

      const { category, modelParams } = model;

      if (
        (!params || params.no_subcategories === undefined) &&
        category.default_list_filter === "none" &&
        filterArg === "default" &&
        modelParams
      ) {
        // TODO: avoid throwing away preload data by redirecting on the server
        PreloadStore.getAndRemove("topic_list");
        return this.replaceWith(
          "discovery.categoryNone",
          modelParams.category_slug_path_with_id
        );
      }

      return all([
        this._createSubcategoryList(category),
        this._retrieveTopicList(category, transition, modelParams),
      ]);
    },

    filter(category) {
      return filterArg === "default"
        ? category.get("default_view") || "latest"
        : filterArg;
    },

    _navigationArgs(category) {
      const noSubcategories = params && !!params.no_subcategories,
        filterType = this.filter(category).split("/")[0];

      return {
        category,
        filterType,
        noSubcategories,
      };
    },

    _createSubcategoryList(category) {
      this._categoryList = null;

      if (category.isParent && category.show_subcategory_list) {
        return CategoryList.listForParent(this.store, category).then(
          (list) => (this._categoryList = list)
        );
      }

      // If we're not loading a subcategory list just resolve
      return Promise.resolve();
    },

    _retrieveTopicList(category, transition, modelParams) {
      const findOpts = filterQueryParams(modelParams, params);
      const extras = { cached: this.isPoppedState(transition) };

      let listFilter = `c/${Category.slugFor(category)}/${category.id}`;
      if (findOpts.no_subcategories) {
        listFilter += "/none";
      }
      listFilter += `/l/${this.filter(category)}`;

      return findTopicList(
        this.store,
        this.topicTrackingState,
        listFilter,
        findOpts,
        extras
      ).then((list) => {
        TopicList.hideUniformCategory(list, category);
        this.set("topics", list);
        return list;
      });
    },

    titleToken() {
      const category = this.currentModel.category;

      const filterText = I18n.t(
        "filters." + this.filter(category).replace("/", ".") + ".title"
      );

      let categoryName = category.name;
      if (category.parent_category_id) {
        const list = Category.list();
        const parentCategory = list.findBy("id", category.parent_category_id);
        categoryName = `${parentCategory.name}/${categoryName}`;
      }

      return I18n.t("filters.with_category", {
        filter: filterText,
        category: categoryName,
      });
    },

    get canCreateTopicOnCategory() {
      const topics = this.topics,
        category = this.model.category,
        canCreateTopic = topics.get("can_create_topic");
      return (
        canCreateTopic && category?.get("permission") === PermissionType.FULL
      );
    },

    setupController(controller, model) {
      const topics = this.topics,
        category = model.category,
        canCreateTopic = topics.get("can_create_topic");

      // let defaultSubcategory;
      // let canCreateTopicOnSubCategory;

      // if (this.siteSettings.default_subcategory_on_read_only_category) {
      //   cannotCreateTopicOnCategory = false;

      //   if (!canCreateTopicOnCategory && category.subcategories) {
      //     defaultSubcategory = category.subcategories.find((subcategory) => {
      //       return subcategory.get("permission") === PermissionType.FULL;
      //     });
      //     canCreateTopicOnSubCategory = !!defaultSubcategory;
      //   }
      // }

      // this.controllerFor("navigation/category").setProperties({
      //   // canCreateTopicOnCategory,
      //   // cannotCreateTopicOnCategory,
      //   canCreateTopic,
      //   canCreateTopicOnSubCategory,
      //   defaultSubcategory,
      // });

      controller.setProperties({
        discovery: this.controllerFor("discovery"),
        navigationArgs: this._navigationArgs(category),
      });

      let topicOpts = {
        model: topics,
        category,
        period:
          topics.get("for_period") ||
          (model.modelParams && model.modelParams.period),
        selected: [],
        noSubcategories: params && !!params.no_subcategories,
        expandAllPinned: true,
        canCreateTopic,
        canCreateTopicOnCategory: this.canCreateTopicOnCategory,
        // canCreateTopicOnSubCategory,
        // defaultSubcategory,
      };

      const p = category.get("params");
      if (p && Object.keys(p).length) {
        if (p.order !== undefined) {
          topicOpts.order = p.order;
        }
        if (p.ascending !== undefined) {
          topicOpts.ascending = p.ascending;
        }
      }

      this.controllerFor("discovery/topics").setProperties(topicOpts);
      this.searchService.searchContext = category.get("searchContext");
      this.set("topics", null);
    },

    renderTemplate() {
      if (this._categoryList) {
        this.render("discovery/categories", {
          outlet: "header-list-container",
          model: this._categoryList,
        });
      } else {
        this.disconnectOutlet({ outlet: "header-list-container" });
      }
      this.render("discovery/topics", {
        controller: "discovery/topics",
        outlet: "list-container",
      });
      this.render();
    },

    deactivate() {
      this._super(...arguments);

      this.composer.set("prioritizedCategoryId", null);
      this.searchService.searchContext = null;
    },

    @action
    setNotification(notification_level) {
      this.currentModel.setNotification(notification_level);
    },

    @action
    triggerRefresh() {
      this.refresh();
    },

    @action
    changeSort(sortBy) {
      changeSort.call(this, sortBy);
    },

    @action
    resetParams(skipParams = []) {
      resetParams.call(this, skipParams);
    },
  });
};
