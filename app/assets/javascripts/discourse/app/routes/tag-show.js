import {
  filterQueryParams,
  findTopicList,
} from "discourse/routes/build-topic-route";
import {
  queryParams,
  resetParams,
} from "discourse/controllers/discovery-sortable";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import DiscourseRoute from "discourse/routes/discourse";
import FilterModeMixin from "discourse/mixins/filter-mode";
import I18n from "I18n";
import PermissionType from "discourse/models/permission-type";
import { escapeExpression } from "discourse/lib/utilities";
import { makeArray } from "discourse-common/lib/helpers";
import { setTopicList } from "discourse/lib/topic-list-tracker";
import showModal from "discourse/lib/show-modal";
import { action } from "@ember/object";
import PreloadStore from "discourse/lib/preload-store";
import { inject as service } from "@ember/service";

const NONE = "none";
const ALL = "all";

export default DiscourseRoute.extend(FilterModeMixin, {
  composer: service(),
  navMode: "latest",

  queryParams,

  controllerName: "tag.show",
  templateName: "tag.show",

  beforeModel() {
    const controller = this.controllerFor("tag.show");
    controller.setProperties({
      loading: true,
      showInfo: false,
    });
  },

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

    const filterType = this.navMode.split("/")[0];

    let tagNotification;
    if (tag && tag.id !== NONE && this.currentUser) {
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
      return this.replaceWith(
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

    setTopicList(list);

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
  },

  setupController(controller, model) {
    const noSubcategories = this.noSubcategories;

    this.controllerFor("tag.show").setProperties({
      model: model.tag,
      ...model,
      period: model.list.for_period,
      navMode: this.navMode,
      noSubcategories,
      loading: false,
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

      this.searchService.set("searchContext", tagIntersectionSearchContext);
    } else {
      this.searchService.set("searchContext", model.tag.searchContext);
    }
  },

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
  },

  deactivate() {
    this._super(...arguments);
    this.searchService.set("searchContext", null);
  },

  @action
  renameTag(tag) {
    showModal("rename-tag", { model: tag });
  },

  @action
  createTopic() {
    if (this.currentUser?.has_topic_draft) {
      this.openTopicDraft();
    } else {
      const controller = this.controllerFor("tag.show");
      this.composer
        .open({
          categoryId: controller.category?.id,
          action: Composer.CREATE_TOPIC,
          draftKey: Composer.NEW_TOPIC_KEY,
        })
        .then(() => {
          // Pre-fill the tags input field
          if (this.composer.canEditTags && controller.tag?.id) {
            const composerModel = this.composer.model;
            composerModel.set("tags", this._controllerTags(controller));
          }
        });
    }
  },

  @action
  dismissReadTopics(dismissTopics) {
    const operationType = dismissTopics ? "topics" : "posts";
    this.send("dismissRead", operationType);
  },

  @action
  dismissRead(operationType) {
    const controller = this.controllerFor("tag-show");
    let options = {
      tagName: controller.tag?.id,
    };
    const categoryId = controller.category?.id;

    if (categoryId) {
      options = Object.assign({}, options, {
        categoryId,
        includeSubcategories: !controller.noSubcategories,
      });
    }

    controller.send("dismissRead", operationType, options);
  },

  @action
  resetParams(skipParams = []) {
    resetParams.call(this, skipParams);
  },

  @action
  didTransition() {
    this.controllerFor("tag.show")._showFooter();
    return true;
  },

  _controllerTags(controller) {
    return [controller.get("model.id"), ...makeArray(controller.additionalTags)]
      .filter(Boolean)
      .filter((tag) => ![NONE, ALL].includes(tag));
  },
});
