import { action } from "@ember/object";
import { service } from "@ember/service";
import { hash } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { MAX_UNOPTIMIZED_CATEGORIES } from "discourse/lib/constants";
import PreloadStore from "discourse/lib/preload-store";
import { defaultHomepage } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import CategoryList from "discourse/models/category-list";
import TopicList from "discourse/models/topic-list";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class DiscoveryCategoriesRoute extends DiscourseRoute {
  @service modal;
  @service router;
  @service session;

  templateName = "discovery/categories";
  controllerName = "discovery/categories";

  async findCategories(parentCategory) {
    let model;

    let style =
      this.site.desktopView && this.siteSettings.desktop_category_page_style;
    if (this.site.categories.length > MAX_UNOPTIMIZED_CATEGORIES) {
      style = "categories_only";
    }

    if (
      style === "categories_and_latest_topics" ||
      style === "categories_and_latest_topics_created_date"
    ) {
      model = await this._findCategoriesAndTopics("latest", parentCategory);
    } else if (style === "categories_and_top_topics") {
      model = await this._findCategoriesAndTopics("top", parentCategory);
    } else {
      // The server may have serialized this. Based on the logic above, we don't need it
      // so remove it to avoid it being used later by another TopicList route.
      PreloadStore.remove("topic_list");
      model = await CategoryList.list(this.store, parentCategory);
    }

    return model;
  }

  async model(params) {
    let parentCategory;
    if (params.category_slug_path_with_id) {
      parentCategory = this.site.lazy_load_categories
        ? await Category.asyncFindBySlugPathWithID(
            params.category_slug_path_with_id
          )
        : Category.findBySlugPathWithID(params.category_slug_path_with_id);
    }

    return this.findCategories(parentCategory).then((model) => {
      const tracking = this.topicTrackingState;
      if (tracking) {
        tracking.sync(model, "categories");
        tracking.trackIncoming("categories");
      }
      return model;
    });
  }

  _loadBefore(store) {
    const session = this.session;

    return function (topic_ids, storeInSession) {
      // refresh dupes
      this.topics.removeObjects(
        this.topics.filter((topic) => topic_ids.includes(topic.id))
      );

      const url = `/latest.json?topic_ids=${topic_ids.join(",")}`;

      return ajax({ url, data: this.params }).then((result) => {
        const topicIds = new Set();
        this.topics.forEach((topic) => topicIds.add(topic.id));

        let i = 0;
        TopicList.topicsFrom(store, result).forEach((topic) => {
          if (!topicIds.has(topic.id)) {
            topic.set("highlight", true);
            this.topics.insertAt(i, topic);
            i++;
          }
        });

        if (storeInSession) {
          session.set("topicList", this);
        }
      });
    };
  }

  async _findCategoriesAndTopics(filter, parentCategory = null) {
    return hash({
      categoriesList: PreloadStore.getAndRemove("categories_list"),
      topicsList: PreloadStore.getAndRemove("topic_list"),
    })
      .then((result) => {
        if (
          result.categoriesList?.category_list &&
          result.topicsList?.topic_list
        ) {
          return { ...result.categoriesList, ...result.topicsList };
        } else {
          // Otherwise, return the ajax result
          const data = {};
          if (parentCategory) {
            data.parent_category_id = parentCategory.id;
          }
          return ajax(`/categories_and_${filter}`, { data });
        }
      })
      .then((result) => {
        if (result.topic_list?.top_tags) {
          this.site.set("top_tags", result.topic_list.top_tags);
        }

        return CategoryList.create({
          store: this.store,
          categories: CategoryList.categoriesFrom(
            this.store,
            result,
            parentCategory
          ),
          parentCategory,
          topics: TopicList.topicsFrom(this.store, result),
          can_create_category: result.category_list.can_create_category,
          can_create_topic: result.category_list.can_create_topic,
          loadBefore: this._loadBefore(this.store),
        });
      });
  }

  titleToken() {
    if (defaultHomepage() === "categories") {
      return;
    }
    return i18n("filters.categories.title");
  }

  setupController(controller) {
    controller.setProperties({
      discovery: this.controllerFor("discovery"),
    });

    super.setupController(...arguments);
  }

  @action
  triggerRefresh() {
    this.refresh();
  }
}
