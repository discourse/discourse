import Controller from "@ember/controller";
import { action } from "@ember/object";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { setTopicList } from "discourse/lib/topic-list-tracker";
import { inject as service } from "@ember/service";
import { categoriesComponent } from "./categories";
import { getOwner } from "@ember/application";
import { tracked } from "@glimmer/tracking";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import BulkSelectHelper from "discourse/lib/bulk-select-helper";
import { defineTrackedProperty } from "discourse/lib/tracked-tools";

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
export default class DiscoveryListController extends Controller {
  @service composer;
  @service siteSettings;
  @service site;
  @service currentUser;

  @tracked model;
  @tracked subcategoryList;

  queryParams = Object.keys(queryParams);

  bulkSelectHelper = new BulkSelectHelper(this);

  constructor() {
    super(...arguments);
    for (const [name, info] of Object.entries(queryParams)) {
      defineTrackedProperty(this, name, info.default);
    }
  }

  get canBulkSelect() {
    return (
      this.currentUser?.canManageTopic ||
      this.showDismissRead ||
      this.showResetNew
    );
  }

  get showDismissRead() {
    return (
      filterTypeForMode(this.model?.filter) === "unread" &&
      this.model.get("topics.length") > 0
    );
  }

  get showResetNew() {
    return (
      filterTypeForMode(this.model?.filter) === "new" &&
      this.model?.get("topics.length") > 0
    );
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
  createTopic() {
    this.composer.openNewTopic({
      category: this.createTopicTargetCategory,
      tags: [this.tag?.id, ...(this.additionalTags ?? [])]
        .filter(Boolean)
        .reject((t) => ["none", "all"].includes(t))
        .join(","),
      preferDraft: true,
    });
  }

  @action
  setTrackingTopicList(model) {
    setTopicList(model);
  }

  @action
  changePeriod(p) {
    this.period = p;
  }

  @action
  changeSort(sortBy) {
    if (sortBy === this.order) {
      this.ascending = !this.ascending;
      this.model.updateSortParams(sortBy, this.ascending);
    } else {
      this.order = sortBy;
      this.ascending = false;
      this.model.updateSortParams(sortBy, false);
    }
  }

  @action
  changeNewListSubset(subset) {
    this.subset = subset;
    this.model.updateNewListSubsetParam(subset);
  }

  @action
  toggleTagInfo() {
    this.toggleProperty("showTagInfo");
  }
}
