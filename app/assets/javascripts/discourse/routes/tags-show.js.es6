import Composer from "discourse/models/composer";
import showModal from "discourse/lib/show-modal";
import { findTopicList } from "discourse/routes/build-topic-route";
import PermissionType from "discourse/models/permission-type";

export default Discourse.Route.extend({
  navMode: "latest",

  renderTemplate() {
    const controller = this.controllerFor("tags.show");
    this.render("tags.show", { controller });
  },

  model(params) {
    const tag = this.store.createRecord("tag", {
      id: Handlebars.Utils.escapeExpression(params.tag_id)
    });
    let f = "";

    if (params.additional_tags) {
      this.set(
        "additionalTags",
        params.additional_tags.split("/").map(t => {
          return this.store.createRecord("tag", {
            id: Handlebars.Utils.escapeExpression(t)
          }).id;
        })
      );
    } else {
      this.set("additionalTags", null);
    }

    if (params.category) {
      f = "c/";
      if (params.parent_category) {
        f += `${params.parent_category}/`;
      }
      f += `${params.category}/l/`;
    }
    f += this.get("navMode");
    this.set("filterMode", f);

    if (params.category) {
      this.set("categorySlug", params.category);
    }
    if (params.parent_category) {
      this.set("parentCategorySlug", params.parent_category);
    }

    if (tag && tag.get("id") !== "none" && this.get("currentUser")) {
      // If logged in, we should get the tag's user settings
      return this.store
        .find("tagNotification", tag.get("id").toLowerCase())
        .then(tagNotification => {
          this.set("tagNotification", tagNotification);
          return tag;
        });
    }

    return tag;
  },

  titleToken() {
    const filterText = I18n.t(
        `filters.${this.get("navMode").replace("/", ".")}.title`
      ),
      controller = this.controllerFor("tags.show");

    if (controller.get("model.id")) {
      if (this.get("category")) {
        return I18n.t("tagging.filters.with_category", {
          filter: filterText,
          tag: controller.get("model.id"),
          category: this.get("category.name")
        });
      } else {
        return I18n.t("tagging.filters.without_category", {
          filter: filterText,
          tag: controller.get("model.id")
        });
      }
    } else {
      if (this.get("category")) {
        return I18n.t("tagging.filters.untagged_with_category", {
          filter: filterText,
          category: this.get("category.name")
        });
      } else {
        return I18n.t("tagging.filters.untagged_without_category", {
          filter: filterText
        });
      }
    }
  },

  afterModel(model) {
    let filterPath;
    const filter = this.get("navMode");
    const tagId = model ? model.id.toLowerCase() : "none";
    const categorySlug = this.get("categorySlug");
    const parentCategorySlug = this.get("parentCategorySlug");

    if (categorySlug) {
      const category = Discourse.Category.findBySlug(
        categorySlug,
        parentCategorySlug
      );
      if (parentCategorySlug) {
        filterPath = `tags/c/${parentCategorySlug}/${categorySlug}/${tagId}/l/${filter}`;
      } else {
        filterPath = `tags/c/${categorySlug}/${tagId}/l/${filter}`;
      }
      if (category) {
        category.setupGroupsAndPermissions();
        this.set("category", category);
      }
    } else if (this.get("additionalTags")) {
      filterPath = `tags/intersection/${tagId}/${this.get(
        "additionalTags"
      ).join("/")}`;
      this.set("category", null);
    } else {
      filterPath = `tags/${tagId}/l/${filter}`;
      this.set("category", null);
    }

    this.set("filterPath", filterPath);
  },

  setupController(controller, model) {
    controller.set("loading", true);
    const params = controller.getProperties("order", "ascending");

    return findTopicList(
      this.store,
      this.topicTrackingState,
      this.get("filterPath"),
      params,
      {}
    ).then(list => {
      // Update name of tag (case might be different)
      if (list.topic_list.tags) {
        model.set("id", list.topic_list.tags[0].name);
      }

      controller.setProperties({
        list,
        canCreateTopic: list.get("can_create_topic"),
        loading: false,
        canCreateTopicOnCategory:
          this.get("category.permission") === PermissionType.FULL,
        model,
        tag: model,
        additionalTags: this.get("additionalTags"),
        category: this.get("category"),
        filterMode: this.get("filterMode"),
        navMode: this.get("navMode"),
        tagNotification: this.get("tagNotification")
      });
    });
  },

  actions: {
    invalidateModel() {
      this.refresh();
    },

    renameTag(tag) {
      showModal("rename-tag", { model: tag });
    },

    createTopic() {
      const controller = this.controllerFor("tags.show");

      if (controller.get("list.draft")) {
        this.openTopicDraft(controller.get("list"));
      } else {
        this.controllerFor("composer")
          .open({
            categoryId: controller.get("category.id"),
            action: Composer.CREATE_TOPIC,
            draftKey: controller.get("list.draft_key"),
            draftSequence: controller.get("list.draft_sequence")
          })
          .then(() => {
            // Pre-fill the tags input field
            if (controller.get("model.id")) {
              const composerModel = this.controllerFor("composer").get("model");
              composerModel.set(
                "tags",
                _.compact(
                  _.flatten([
                    controller.get("model.id"),
                    controller.get("additionalTags")
                  ])
                )
              );
            }
          });
      }
    },

    didTransition() {
      this.controllerFor("tags.show")._showFooter();
      return true;
    }
  }
});
