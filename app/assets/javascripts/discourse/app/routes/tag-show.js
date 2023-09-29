import { inject as service } from "@ember/service";
import {
  filterQueryParams,
  findTopicList,
} from "discourse/routes/build-topic-route";
import { queryParams, resetParams } from "discourse/controllers/discovery/list";
import Category from "discourse/models/category";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import PermissionType from "discourse/models/permission-type";
import { escapeExpression } from "discourse/lib/utilities";
import { action } from "@ember/object";
import PreloadStore from "discourse/lib/preload-store";
import { filterTypeForMode } from "discourse/lib/filter-mode";

const NONE = "none";
const ALL = "all";

export default class TagShowRoute extends DiscourseRoute {
  @service composer;
  @service router;
  @service currentUser;

  queryParams = queryParams;
  controllerName = "discovery/list";
  templateName = "discovery/list";
  routeConfig = {};

  get navMode() {
    return this.routeConfig.navMode || "latest";
  }

  get noSubcategories() {
    return this.routeConfig.noSubcategories;
  }

  beforeModel() {
    const controller = this.controllerFor("tag.show");
    controller.setProperties({
      loading: true,
      showInfo: false,
    });
  }

  async model(params, transition) {
    const tag = this.store.createRecord("tag", {
      id: escapeExpression(params.tag_id),
    });

    let additionalTags;

    if (params.additional_tags) {
      additionalTags = params.additional_tags.split("/").map((t) => {
        return this.store.createRecord("tag", {
          id: escapeExpression(t),
        }).id;
      });
    }

    const filterType = filterTypeForMode(this.navMode);

    let tagNotification;
    if (tag && tag.id !== NONE && this.currentUser && !additionalTags) {
      // If logged in, we should get the tag's user settings
      tagNotification = await this.store.find(
        "tagNotification",
        tag.id.toLowerCase()
      );
    }

    const category = params.category_slug_path_with_id
      ? Category.findBySlugPathWithID(params.category_slug_path_with_id)
      : null;
    const filteredQueryParams = filterQueryParams(
      transition.to.queryParams,
      {}
    );
    const topicFilter = this.navMode;
    const tagId = tag ? tag.id.toLowerCase() : NONE;
    let filter;

    if (category) {
      category.setupGroupsAndPermissions();
      filter = `tags/c/${Category.slugFor(category)}/${category.id}`;

      if (this.noSubcategories !== undefined) {
        filter += this.noSubcategories ? `/${NONE}` : `/${ALL}`;
      }

      filter += `/${tagId}/l/${topicFilter}`;
    } else if (additionalTags) {
      filter = `tags/intersection/${tagId}/${additionalTags.join("/")}`;
    } else {
      filter = `tag/${tagId}/l/${topicFilter}`;
    }

    if (
      this.noSubcategories === undefined &&
      category?.default_list_filter === "none" &&
      topicFilter === "latest"
    ) {
      // TODO: avoid throwing away preload data by redirecting on the server
      PreloadStore.getAndRemove("topic_list");
      return this.router.replaceWith(
        "tags.showCategoryNone",
        params.category_slug_path_with_id,
        tagId
      );
    }

    const list = await findTopicList(
      this.store,
      this.topicTrackingState,
      filter,
      filteredQueryParams,
      {
        cached: this.isPoppedState(transition),
      }
    );

    if (list.topic_list.tags && list.topic_list.tags.length === 1) {
      // Update name of tag (case might be different)
      tag.setProperties({
        id: list.topic_list.tags[0].name,
        staff: list.topic_list.tags[0].staff,
      });
    }

    return {
      tag,
      category,
      list,
      additionalTags,
      filterType,
      tagNotification,
      canCreateTopic: list.can_create_topic,
      canCreateTopicOnCategory: category?.permission === PermissionType.FULL,
      canCreateTopicOnTag: !tag.staff || this.currentUser?.staff,
    };
  }

  setupController(controller, model) {
    controller.setProperties({
      model: model.list,
      tag: model.tag,
      category: model.category,
      additionalTags: model.additionalTags,
      filterType: model.filterType,
      noSubcategories: this.noSubcategories,
      canCreateTopicOnTag: model.canCreateTopicOnTag,
      navigationArgs: {
        filterType: model.filterType,
        category: model.category,
        tag: model.tag,
      },
      tagNotification: model.tagNotification,
    });

    if (model.category || model.additionalTags) {
      const tagIntersectionSearchContext = {
        type: "tagIntersection",
        tagId: model.tag.id,
        tag: model.tag,
        additionalTags: model.additionalTags || null,
        categoryId: model.category?.id || null,
        category: model.category || null,
      };

      this.searchService.searchContext = tagIntersectionSearchContext;
    } else {
      this.searchService.searchContext = model.tag.searchContext;
    }
  }

  titleToken() {
    const filterText = I18n.t(
      `filters.${this.navMode.replace("/", ".")}.title`
    );
    const controller = this.controllerFor("tag.show");

    if (controller.tag?.id) {
      if (controller.category) {
        return I18n.t("tagging.filters.with_category", {
          filter: filterText,
          tag: controller.tag.id,
          category: controller.category.name,
        });
      } else {
        return I18n.t("tagging.filters.without_category", {
          filter: filterText,
          tag: controller.tag.id,
        });
      }
    } else {
      if (controller.category) {
        return I18n.t("tagging.filters.untagged_with_category", {
          filter: filterText,
          category: controller.category.name,
        });
      } else {
        return I18n.t("tagging.filters.untagged_without_category", {
          filter: filterText,
        });
      }
    }
  }

  deactivate() {
    super.deactivate(...arguments);
    this.searchService.searchContext = null;
  }

  @action
  resetParams(skipParams = []) {
    resetParams.call(this, skipParams);
  }
}

export function buildTagRoute(routeConfig = {}) {
  return class extends TagShowRoute {
    routeConfig = routeConfig;
  };
}
