import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { underscore } from "@ember/string";
import { isPresent } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { REVIEWABLE_UNKNOWN_TYPE_SOURCE } from "discourse/lib/constants";
import { dsaCategoryLabel } from "discourse/lib/dsa-classification";
import { i18n } from "discourse-i18n";

export const DSA_CLASSIFICATION_STATUS = "dsa_classification";
const UNCLASSIFIED_DSA_CATEGORY = "unclassified";

export default class ReviewIndexController extends Controller {
  @service currentUser;
  @service site;
  @service dialog;
  @service siteSettings;
  @service toasts;

  queryParams = [
    "priority",
    "type",
    "status",
    "category_id",
    "topic_id",
    "username",
    "reviewed_by",
    "claimed_by",
    "from_date",
    "to_date",
    "sort_order",
    "additional_filters",
    "flagged_by",
    "score_type",
    "dsa_category",
  ];

  type = null;
  status = "pending";
  dsa_category = null;
  priority = this.siteSettings.reviewable_default_visibility;
  category_id = null;
  reviewables = null;
  topic_id = null;
  filtersExpanded = false;
  username = "";
  reviewed_by = "";
  claimed_by = "";
  flagged_by = "";
  from_date = null;
  to_date = null;
  sort_order = null;
  additional_filters = null;
  filterScoreType = null;
  unknownTypeSource = REVIEWABLE_UNKNOWN_TYPE_SOURCE;

  @computed("reviewableTypes")
  get allTypes() {
    return (this.reviewableTypes || []).map((type) => {
      const translationKey = underscore(type).replace(/[^\w]+/g, "_");

      return {
        id: type,
        name: i18n(`review.types.${translationKey}.title`),
      };
    });
  }

  // The type filter becomes a DSA category filter while filtering by classification.
  @computed("filterStatus")
  get filteringByDsaClassification() {
    return this.filterStatus === DSA_CLASSIFICATION_STATUS;
  }

  @computed("site.dsa_taxonomy")
  get allDsaCategories() {
    const categories = Object.values(this.site.dsa_taxonomy ?? {}).flatMap(
      (c) => Object.keys(c)
    );

    return [
      {
        id: UNCLASSIFIED_DSA_CATEGORY,
        name: i18n("review.filters.dsa_category.unclassified"),
      },
      ...categories.map((id) => ({ id, name: dsaCategoryLabel(id) })),
    ];
  }

  @computed("scoreTypes")
  get allScoreTypes() {
    return this.scoreTypes || [];
  }

  @computed
  get priorities() {
    return ["any", "low", "medium", "high"].map((priority) => {
      return {
        id: priority,
        name: i18n(`review.filters.priority.${priority}`),
      };
    });
  }

  @computed
  get sortOrders() {
    return ["score", "score_asc", "created_at", "created_at_asc"].map(
      (order) => {
        return {
          id: order,
          name: i18n(`review.filters.orders.${order}`),
        };
      }
    );
  }

  @computed("siteSettings.enable_dsa_reporting")
  get statuses() {
    return [
      "pending",
      "approved",
      "rejected",
      "deleted",
      "ignored",
      "reviewed",
      ...(this.siteSettings.enable_dsa_reporting
        ? [DSA_CLASSIFICATION_STATUS]
        : []),
      "all",
    ].map((id) => {
      return { id, name: i18n(`review.statuses.${id}.title`) };
    });
  }

  @computed("filtersExpanded")
  get toggleFiltersIcon() {
    return this.filtersExpanded ? "chevron-up" : "chevron-down";
  }

  @computed("unknownReviewableTypes")
  get displayUnknownReviewableTypesWarning() {
    return this.unknownReviewableTypes?.length > 0 && this.currentUser.admin;
  }

  setRange(range) {
    this.setProperties(range);
  }

  refreshModel() {
    next(() => this.send("refreshRoute"));
  }

  @action
  remove(ids) {
    if (!ids) {
      return;
    }

    let newList = this.reviewables.content.filter(
      (reviewable) => !ids.includes(reviewable.id)
    );

    if (newList.length === 0) {
      this.refreshModel();
    } else {
      this.reviewables.content.splice(0, Infinity, ...newList);
    }
  }

  @action
  updateStatuses(updates) {
    this.reviewables.content.forEach((reviewable) => {
      const update = updates[reviewable.id];

      if (update) {
        reviewable.setProperties(update);
      }
    });
  }

  @action
  resetTopic() {
    this.set("topic_id", null);
    this.refreshModel();
  }

  @action
  ignoreAllUnknownTypes() {
    return this.dialog.deleteConfirm({
      message: i18n("review.unknown.delete_confirm"),
      didConfirm: async () => {
        try {
          await ajax("/admin/unknown_reviewables/destroy", {
            type: "delete",
          });
          this.set("unknownReviewableTypes", []);
          this.toasts.success({
            data: { message: i18n("review.unknown.ignore_success") },
          });
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  @action
  refresh() {
    const currentStatus = this.status;
    const nextStatus = this.filterStatus;
    const currentOrder = this.sort_order;
    let nextOrder = this.filterSortOrder;

    const createdAtStatuses = ["reviewed", "all", DSA_CLASSIFICATION_STATUS];
    const priorityStatuses = [
      "approved",
      "rejected",
      "deleted",
      "ignored",
      "pending",
    ];

    if (
      createdAtStatuses.includes(currentStatus) &&
      currentOrder === "created_at" &&
      priorityStatuses.includes(nextStatus) &&
      nextOrder === "created_at"
    ) {
      nextOrder = "score";
    }

    if (
      priorityStatuses.includes(currentStatus) &&
      currentOrder === "score" &&
      createdAtStatuses.includes(nextStatus) &&
      nextOrder === "score"
    ) {
      nextOrder = "created_at";
    }

    this.setProperties({
      type: this.filteringByDsaClassification ? null : this.filterType,
      dsa_category: this.filteringByDsaClassification
        ? this.filterDsaCategory
        : null,
      priority: this.filterPriority,
      status: this.filterStatus,
      category_id: this.filterCategoryId,
      username: this.filterUsername,
      reviewed_by: this.filterReviewedBy,
      claimed_by: this.filterClaimedBy,
      flagged_by: this.filterFlaggedBy,
      score_type: this.filterScoreType,
      from_date: isPresent(this.filterFromDate)
        ? this.filterFromDate.toISOString(true).split("T")[0]
        : null,
      to_date: isPresent(this.filterToDate)
        ? this.filterToDate.toISOString(true).split("T")[0]
        : null,
      sort_order: nextOrder,
      additional_filters: JSON.stringify(this.additionalFilters),
    });

    this.refreshModel();
  }

  @action
  loadMore() {
    return this.reviewables.loadMore();
  }

  @action
  toggleFilters() {
    this.toggleProperty("filtersExpanded");
  }

  @action
  updateFilterReviewedBy(selected) {
    this.set("filterReviewedBy", selected.firstObject);
  }

  @action
  updateFilterClaimedBy(selected) {
    this.set("filterClaimedBy", selected.firstObject);
  }

  @action
  updateFilterFlaggedBy(selected) {
    this.set("filterFlaggedBy", selected.firstObject);
  }

  @action
  updateFilterUsername(selected) {
    this.set("filterUsername", selected.firstObject);
  }
}
