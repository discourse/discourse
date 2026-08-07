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

    withPluginApi((api) => {
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

      api.registerValueTransformer(
        "composer-actions-content",
        ({ value, context }) => {
          const { action, composerModel } = context;

          if (action === CREATE_TOPIC) {
            if (
              composerModel.createAsPostVoting &&
              !composerModel.onlyPostVotingInThisCategory
            ) {
              value.push({
                name: i18n(
                  "composer.composer_actions.remove_as_post_voting.label"
                ),
                description: i18n(
                  "composer.composer_actions.remove_as_post_voting.desc"
                ),
                icon: "plus",
                id: "togglePostVoting",
              });
            } else if (!composerModel.onlyPostVotingInThisCategory) {
              value.push({
                name: i18n(
                  "composer.composer_actions.create_as_post_voting.label"
                ),
                description: i18n(
                  "composer.composer_actions.create_as_post_voting.desc"
                ),
                icon: "plus",
                id: "togglePostVoting",
              });
            }
          }

          return value;
        }
      );

      api.registerBehaviorTransformer(
        "composer-actions-on-select",
        ({ context, next }) => {
          if (context.actionId === "togglePostVoting") {
            context.model.toggleProperty("createAsPostVoting");
            context.model.notifyPropertyChange("replyOptions");
            context.model.notifyPropertyChange("action");
          } else {
            next();
          }
        }
      );

      // Purely derived from the category.
      api.addModelGetter(
        "composer",
        "onlyPostVotingInThisCategory",
        function () {
          return (
            this.creatingTopic &&
            !!this.category?.only_post_voting_in_this_category
          );
        }
      );

      // Defaults from the category (forced on when it's post-voting-only),
      // resets on category change, and is user-toggleable until then.
      api.addModelField("composer", "createAsPostVoting", {
        resettable: true,
        defaultValue() {
          if (!this.creatingTopic) {
            return false;
          }

          return (
            this.onlyPostVotingInThisCategory ||
            !!this.category?.create_as_post_voting_default
          );
        },
      });
    });
  },
};
