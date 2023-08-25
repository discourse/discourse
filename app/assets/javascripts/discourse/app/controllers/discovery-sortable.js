import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { setTopicList } from "discourse/lib/topic-list-tracker";
import { inject as service } from "@ember/service";
import { categoriesComponent } from "./discovery/categories";
import { getOwner } from "@ember/application";
import { tracked } from "@glimmer/tracking";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import { or } from "@ember/object/computed";
import BulkSelectHelper from "discourse/lib/bulk-select-helper";

// Just add query params here to have them automatically passed to topic list filters.
export const queryParams = {
  order: { replace: true, refreshModel: true },
  ascending: { replace: true, refreshModel: true, default: false },
  status: { replace: true, refreshModel: true },
  state: { replace: true, refreshModel: true },
  search: { replace: true, refreshModel: true },
  max_posts: { replace: true, refreshModel: true },
  min_posts: { replace: true, refreshModel: true },
  q: { replace: true, refreshModel: true },
  before: { replace: true, refreshModel: true },
  bumped_before: { replace: true, refreshModel: true },
  f: { replace: true, refreshModel: true },
  subset: { replace: true, refreshModel: true },
  period: { replace: true, refreshModel: true },
  topic_ids: { replace: true, refreshModel: true },
  group_name: { replace: true, refreshModel: true },
  tags: { replace: true, refreshModel: true },
  match_all_tags: { replace: true, refreshModel: true },
  no_subcategories: { replace: true, refreshModel: true },
  no_tags: { replace: true, refreshModel: true },
  exclude_tag: { replace: true, refreshModel: true },
};

export function changeSort(sortBy) {
  let model = this.controllerFor("discovery.topics").model;

  if (sortBy === this.controller.order) {
    this.controller.toggleProperty("ascending");
    model.updateSortParams(sortBy, this.controller.ascending);
  } else {
    this.controller.setProperties({ order: sortBy, ascending: false });
    model.updateSortParams(sortBy, false);
  }
}

export function changeNewListSubset(subset) {
  this.controller.set("subset", subset);

  let model = this.controllerFor("discovery.topics").model;
  model.updateNewListSubsetParam(subset);
}

export function resetParams(skipParams = []) {
  Object.keys(queryParams).forEach((p) => {
    if (!skipParams.includes(p)) {
      this.controller.set(p, queryParams[p].default);
    }
  });
}

export function addDiscoveryQueryParam(p, opts) {
  queryParams[p] = opts;
}

@disableImplicitInjections
export default class DiscoverySortableController extends Controller.extend() {
  @service composer;
  @service siteSettings;
  @service site;

  @tracked subcategoryList;
  bulkSelectHelper = new BulkSelectHelper(this);

  @or("currentUser.canManageTopic", "showDismissRead", "showResetNew")
  canBulkSelect;

  queryParams = Object.keys(queryParams);

  constructor() {
    super(...arguments);
    this.queryParams.forEach((p) => {
      this[p] = queryParams[p].default;
    });
  }

  get bulkSelectEnabled() {
    return this.bulkSelectHelper.bulkSelectEnabled;
  }

  get selected() {
    return this.bulkSelectHelper.selected;
  }

  @discourseComputed("model.filter", "model.topics.length")
  showDismissRead(filterMode, topicsLength) {
    return filterTypeForMode(filterMode) === "unread" && topicsLength > 0;
  }

  @discourseComputed("model.filter", "model.topics.length")
  showResetNew(filterMode, topicsLength) {
    return filterTypeForMode(filterMode) === "new" && topicsLength > 0;
  }

  @action
  createTopic() {
    this.composer.openNewTopic({
      category: this.createTopicTargetCategory,
      preferDraft: true,
    });
  }

  get createTopicTargetCategory() {
    if (this.category?.canCreateTopic) {
      return this.category;
    }

    if (this.siteSettings.default_subcategory_on_read_only_category) {
      return this.category?.subcategoryWithCreateTopicPermission;
    }
  }

  get createTopicDisabled() {
    // We are in a category route, but user does not have permission for the category
    return this.category && !this.createTopicTargetCategory;
  }

  get subcategoriesComponent() {
    if (this.subcategoryList) {
      const componentName = categoriesComponent({
        site: this.site,
        siteSettings: this.siteSettings,
        parentCategory: this.subcategoryList.parentCategory,
      });

      // Todo, the `categoriesComponent` function should return a component class instead of a string
      return getOwner(this).resolveRegistration(`component:${componentName}`);
    }
  }

  @action
  setTrackingTopicList(model) {
    setTopicList(model);
  }

  @action
  changePeriod(p) {
    this.set("period", p);
  }

  @action
  toggleBulkSelect() {
    this.bulkSelectHelper.toggleBulkSelect();
  }

  @action
  dismissRead(operationType, options) {
    this.bulkSelectHelper.dismissRead(operationType, options);
  }

  @action
  updateAutoAddTopicsToBulkSelect(value) {
    this.bulkSelectHelper.autoAddTopicsToBulkSelect = value;
  }

  @action
  addTopicsToBulkSelect(topics) {
    this.bulkSelectHelper.addTopics(topics);
  }
}
