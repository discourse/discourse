import { action } from "@ember/object";
import { service } from "@ember/service";
import { queryParams, resetParams } from "discourse/controllers/discovery/list";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import PreloadStore from "discourse/lib/preload-store";
import { setTopicList } from "discourse/lib/topic-list-tracker";
import Category from "discourse/models/category";
import CategoryList from "discourse/models/category-list";
import TopicList from "discourse/models/topic-list";
import {
  filterQueryParams,
  findTopicList,
} from "discourse/routes/build-topic-route";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

@disableImplicitInjections
class AbstractCategoryRoute extends DiscourseRoute {
  @service composer;
  @service router;
  @service site;
  @service store;
  @service topicTrackingState;
  @service("search") searchService;
  @service historyStore;

  queryParams = queryParams;

  templateName = "discovery/list";
  controllerName = "discovery/list";

  async model(params, transition) {
    const category = this.site.lazy_load_categories
      ? await Category.asyncFindBySlugPathWithID(
          params.category_slug_path_with_id
        )
      : Category.findBySlugPathWithID(params.category_slug_path_with_id);

    if (!category) {
      this.router.replaceWith("/404");
      return;
    }

    if (
      this.routeConfig?.no_subcategories === undefined &&
      category.default_list_filter === "none" &&
      this.routeConfig?.filter === "default" &&
      params
    ) {
      // TODO: avoid throwing away preload data by redirecting on the server
      PreloadStore.getAndRemove("topic_list");
      this.router.replaceWith(
        "discovery.categoryNone",
        params.category_slug_path_with_id
      );
      return;
    }

    const subcategoryListPromise = this._createSubcategoryList(category);
    const topicListPromise = this._retrieveTopicList(
      category,
      transition,
      params
    );

    const noSubcategories = !!this.routeConfig?.no_subcategories;
    const filterType = this.filter(category).split("/")[0];

    return {
      category,
      modelParams: params,
      subcategoryList: await subcategoryListPromise,
      list: await topicListPromise,
      noSubcategories,
      filterType,
    };
  }

  filter(category) {
    return this.routeConfig?.filter === "default"
      ? category.get("default_view") || "latest"
      : this.routeConfig?.filter;
  }

  async _createSubcategoryList(category) {
    if (category.isParent && category.show_subcategory_list) {
      return CategoryList.list(this.store, category);
    }
  }

  async _retrieveTopicList(category, transition, modelParams) {
    const findOpts = filterQueryParams(modelParams, this.routeConfig);
    const extras = { cached: this.historyStore.isPoppedState };

    let listFilter = `c/${Category.slugFor(category)}/${category.id}`;
    if (findOpts.no_subcategories) {
      listFilter += "/none";
    }
    listFilter += `/l/${this.filter(category)}`;

    const topicList = await findTopicList(
      this.store,
      this.topicTrackingState,
      listFilter,
      findOpts,
      extras
    );
    TopicList.hideUniformCategory(topicList, category);

    return topicList;
  }

  titleToken() {
    const category = this.currentModel.category;

    const filterText = i18n(
      "filters." + this.filter(category).replace("/", ".") + ".title"
    );

    let categoryName = category.displayName;
    if (category.parent_category_id) {
      const list = Category.list();
      const parentCategory = list.findBy("id", category.parent_category_id);
      categoryName = `${parentCategory.displayName}/${categoryName}`;
    }

    return i18n("filters.with_category", {
      filter: filterText,
      category: categoryName,
    });
  }

  setupController(controller, model) {
    super.setupController(...arguments);
    controller.bulkSelectHelper.clear();
    this.searchService.searchContext = model.category.get("searchContext");
    setTopicList(model.list);

    const p = model.category.params;
    if (p?.order !== undefined) {
      controller.order = p.order;
    }
    if (p?.ascending !== undefined) {
      controller.ascending = p.ascending;
    }
  }

  deactivate() {
    super.deactivate(...arguments);

    this.composer.set("prioritizedCategoryId", null);
    this.searchService.searchContext = null;
  }

  @action
  setNotification(notification_level) {
    this.currentModel.setNotification(notification_level);
  }

  @action
  triggerRefresh() {
    this.refresh();
  }

  @action
  resetParams(skipParams = []) {
    resetParams.call(this, skipParams);
  }
}

// A helper function to create a category route with parameters
export default function buildCategoryRoute(routeConfig) {
  return class extends AbstractCategoryRoute {
    routeConfig = routeConfig;
  };
}
