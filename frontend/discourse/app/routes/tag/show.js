import { action } from "@ember/object";
import { service } from "@ember/service";
import { queryParams, resetParams } from "discourse/controllers/discovery/list";
import { ajax } from "discourse/lib/ajax";
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
  @service router;
  @service currentUser;
  @service store;
  @service topicTrackingState;
  @service("search") searchService;
  @service historyStore;

  queryParams = queryParams;
  templateName = "discovery/list";
  routeConfig = {};

  get navMode() {
    return this.routeConfig.navMode || "latest";
  }

  get noSubcategories() {
    return this.routeConfig.noSubcategories;
  }

  async model(params, transition) {
    // support both canonical (tag_slug/tag_id) and legacy (tag_name) params
    let slug = params.tag_slug || params.tag_name;
    let id = params.tag_id;

    if (!slug) {
      slug = NONE;
      id = null;
    }

    // handle legacy URLs without tag_id - fetch tag info to get the ID
    // e.g., /tags/c/category/1/my-tag -> need to lookup my-tag to get its ID
    // skip redirect for intersection routes (they use tag_name, not tag_slug/tag_id)
    const isIntersectionRoute = params.additional_tags !== undefined;
    if (slug && slug !== NONE && !id && !isIntersectionRoute) {
      try {
        const result = await ajax(`/tag/${slug}/info.json`);
        if (result.tag_info) {
          id = result.tag_info.id;
          // redirect to canonical URL with ID
          const routeName = transition.to.name;
          const newParams = { ...params, tag_slug: slug, tag_id: id };
          return this.router.replaceWith(routeName, newParams);
        }
      } catch {
        // tag not found, continue with slug only
      }
    }

    // use slug as initial name until API returns actual name
    const tag = this.store.createRecord("tag", {
      id,
      name: slug,
      slug,
    });

    let additionalTags;

    if (params.additional_tags) {
      additionalTags = params.additional_tags.split("/").map((t) => {
        return this.store.createRecord("tag", {
          name: escapeExpression(t),
        }).name;
      });
    }

    const filterType = filterTypeForMode(this.navMode);

    let tagNotification;
    if (tag && slug !== NONE && this.currentUser && !additionalTags) {
      tagNotification = await this.store.find("tagNotification", id);
    }

    let category = params.category_slug_path_with_id
      ? Category.findBySlugPathWithID(params.category_slug_path_with_id)
      : null;
    const filteredQueryParams = filterQueryParams(
      transition.to.queryParams,
      {}
    );
    const topicFilter = this.navMode;
    let filter;

    if (category) {
      category.setupGroupsAndPermissions();
      filter = `tags/c/${Category.slugFor(category)}/${category.id}`;

      if (this.noSubcategories !== undefined) {
        filter += this.noSubcategories ? `/${NONE}` : `/${ALL}`;
      }

      if (slug === NONE) {
        // untagged category route - use "none" without ID
        filter += `/${NONE}/l/${topicFilter}`;
      } else {
        // category+tag routes still use slug/id format
        filter += `/${slug}/${id}/l/${topicFilter}`;
      }
    } else if (additionalTags) {
      filter = `tags/intersection/${slug}/${additionalTags.join("/")}`;

      if (transition.to.queryParams["category"]) {
        filteredQueryParams["category"] = transition.to.queryParams["category"];
        category = Category.findBySlugPathWithID(
          transition.to.queryParams["category"]
        );
      }
    } else {
      // use ID-only format for API calls
      filter = `tag/${id}/l/${topicFilter}`;
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
        slug,
        id
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

    if (list.topic_list.tags && list.topic_list.tags.length >= 1) {
      const mainTagData = list.topic_list.tags.find(
        (t) => t.name.toLowerCase() === slug.toLowerCase() || t.slug === slug
      );
      if (mainTagData) {
        tag.setProperties({
          id: mainTagData.id,
          name: mainTagData.name,
          slug: mainTagData.slug,
          staff: mainTagData.staff,
        });
      }

      if (additionalTags) {
        additionalTags = additionalTags.map((additionalSlug) => {
          const tagData = list.topic_list.tags.find(
            (t) =>
              t.name.toLowerCase() === additionalSlug.toLowerCase() ||
              t.slug === additionalSlug
          );
          return tagData ? tagData.name : additionalSlug;
        });
      }
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
        tagId: model.tag.name,
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

    const tag = model?.tag?.name;
    if (tag && tag !== NONE) {
      if (model.category) {
        return i18n("tagging.filters.with_category", {
          filter: filterText,
          tag: model.tag.name,
          category: model.category.displayName,
        });
      } else {
        return i18n("tagging.filters.without_category", {
          filter: filterText,
          tag: model.tag.name,
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

/** @returns {any} */
export function buildTagRoute(routeConfig = {}) {
  return class extends TagShowRoute {
    routeConfig = routeConfig;
  };
}
