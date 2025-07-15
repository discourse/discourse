import { observer } from "@ember/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import { CREATE_TOPIC } from "discourse/models/composer";
import { i18n } from "discourse-i18n";

export default {
  name: "extend-composer-actions",
  after: "inject-objects",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (!siteSettings.post_voting_enabled) {
      return;
    }

    withPluginApi("0.13.0", (api) => {
      api.serializeOnCreate("create_as_post_voting", "createAsPostVoting");
      api.serializeOnCreate(
        "only_post_voting_in_this_category",
        "onlyPostVotingInThisCategory"
      );

      api.customizeComposerText({
        actionTitle(model) {
          if (model.createAsPostVoting || model.onlyPostVotingInThisCategory) {
            return i18n("composer.create_post_voting.label");
          } else if (model.topic?.is_post_voting) {
            return i18n("post_voting.topic.answer.label");
          } else {
            return null;
          }
        },

        saveLabel(model) {
          if (model.createAsPostVoting || model.onlyPostVotingInThisCategory) {
            return "composer.create_post_voting.label";
          } else if (model.topic?.is_post_voting) {
            return "post_voting.topic.answer.label";
          } else {
            return null;
          }
        },
      });

      api.modifyClass("component:composer-actions", {
        pluginId: "discourse-post-voting",

        togglePostVotingSelected(options, model) {
          model.toggleProperty("createAsPostVoting");
          model.notifyPropertyChange("replyOptions");
          model.notifyPropertyChange("action");
        },
      });

      api.modifySelectKit("composer-actions").appendContent((options) => {
        if (options.action === CREATE_TOPIC) {
          if (
            options.composerModel.createAsPostVoting &&
            !options.composerModel.onlyPostVotingInThisCategory
          ) {
            return [
              {
                name: i18n(
                  "composer.composer_actions.remove_as_post_voting.label"
                ),
                description: i18n(
                  "composer.composer_actions.remove_as_post_voting.desc"
                ),
                icon: "plus",
                id: "togglePostVoting",
              },
            ];
          } else if (options.composerModel.onlyPostVotingInThisCategory) {
            return [];
          } else {
            return [
              {
                name: i18n(
                  "composer.composer_actions.create_as_post_voting.label"
                ),
                description: i18n(
                  "composer.composer_actions.create_as_post_voting.desc"
                ),
                icon: "plus",
                id: "togglePostVoting",
              },
            ];
          }
        } else {
          return [];
        }
      });

      api.modifyClass("model:composer", {
        pluginId: "discourse-post-voting",

        categoryCreateAsPostVotingDefault: observer("categoryId", function () {
          const createAsPostVoting =
            this.category?.create_as_post_voting_default;

          const onlyPostVotingInThisCategory =
            this.category?.only_post_voting_in_this_category;

          if (this.creatingTopic && onlyPostVotingInThisCategory) {
            this.set("createAsPostVoting", true);
            this.set(
              "onlyPostVotingInThisCategory",
              onlyPostVotingInThisCategory
            );
            this.notifyPropertyChange("replyOptions");
            this.notifyPropertyChange("action");
          } else if (
            this.creatingTopic &&
            createAsPostVoting !== this.createAsPostVoting
          ) {
            this.set("createAsPostVoting", createAsPostVoting);
            this.notifyPropertyChange("replyOptions");
            this.notifyPropertyChange("action");
          }
        }),
      });
    });
  },
};
