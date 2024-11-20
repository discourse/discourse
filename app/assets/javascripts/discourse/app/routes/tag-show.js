import { action } from "@ember/object";
import { service } from "@ember/service";
import { queryParams, resetParams } from "discourse/controllers/discovery/list";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import PreloadStore from "discourse/lib/preload-store";
import { setTopicList } from "discourse/lib/topic-list-tracker";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import PermissionType from "discourse/models/permission-type";
import {
  filterQueryParams,
  findTopicList,
} from "discourse/routes/build-topic-route";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

const NONE = "none";
const ALL = "all";

@disableImplicitInjections
export default class TagShowRoute extends DiscourseRoute {
  @service composer;
  @service router;
  @service currentUser;
  @service store;
  @service topicTrackingState;
  @service("search") searchService;
  @service historyStore;

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

    let category = params.category_slug_path_with_id
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

      if (transition.to.queryParams["category"]) {
        filteredQueryParams["category"] = transition.to.queryParams["category"];
        category = Category.findBySlugPathWithID(
          transition.to.queryParams["category"]
        );
      }
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
        cached: this.historyStore.isPoppedState,
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
      noSubcategories: this.noSubcategories,
    };
  }

  setupController(controller, model) {
    super.setupController(...arguments);
    controller.bulkSelectHelper.clear();
    setTopicList(model.list);

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
    const filterText = i18n(`filters.${this.navMode.replace("/", ".")}.title`);
    const model = this.currentModel;

    const tag = model?.tag?.id;
    if (tag && tag !== NONE) {
      if (model.category) {
        return i18n("tagging.filters.with_category", {
          filter: filterText,
          tag: model.tag.id,
          category: model.category.displayName,
        });
      } else {
        return i18n("tagging.filters.without_category", {
          filter: filterText,
          tag: model.tag.id,
        });
      }
    } else {
      if (model.category) {
        return i18n("tagging.filters.untagged_with_category", {
          filter: filterText,
          category: model.category.displayName,
        });
      } else {
        return i18n("tagging.filters.untagged_without_category", {
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
