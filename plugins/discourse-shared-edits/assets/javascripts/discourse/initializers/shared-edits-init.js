import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import { SAVE_ICONS, SAVE_LABELS } from "discourse/models/composer";
import SharedEditButton from "../components/shared-edit-button";

const SHARED_EDIT_ACTION = "sharedEdit";

function initWithApi(api) {
  SAVE_LABELS[SHARED_EDIT_ACTION] = "composer.save_edit";
  SAVE_ICONS[SHARED_EDIT_ACTION] = "pencil";

  customizePostMenu(api);

  const currentUser = api.getCurrentUser();

  api.addPostAdminMenuButton((attrs) => {
    if (!currentUser?.staff && currentUser?.trust_level < 4) {
      return;
    }

    return {
      icon: "far-pen-to-square",
      className: "admin-toggle-shared-edits",
      label: attrs.shared_edits_enabled
        ? "shared_edits.disable_shared_edits"
        : "shared_edits.enable_shared_edits",
      action: async (post) => {
        const url = `/shared_edits/p/${post.id}/${
          post.shared_edits_enabled ? "disable" : "enable"
        }.json`;

        try {
          await ajax(url, { type: "PUT" });
          post.set("shared_edits_enabled", !post.shared_edits_enabled);
        } catch (e) {
          popupAjaxError(e);
        }
      },
    };
  });

  api.addTrackedPostProperties("shared_edits_enabled");

  api.addPostClassesCallback((attrs) => {
    if (attrs.shared_edits_enabled && attrs.canEdit) {
      return ["shared-edits-post"];
    }
  });

  api.modifyClass(
    "model:composer",
    (Superclass) =>
      class extends Superclass {
        get creatingSharedEdit() {
          return this.get("action") === SHARED_EDIT_ACTION;
        }

        get editingPost() {
          return super.editingPost || this.creatingSharedEdit;
        }
      }
  );

  api.modifyClass(
    "controller:topic",
    (Superclass) =>
      class extends Superclass {
        init() {
          super.init(...arguments);

          this.appEvents.on(
            "shared-edit-on-post",
            this,
            this._handleSharedEditOnPost
          );
        }

        willDestroy() {
          super.willDestroy(...arguments);
          this.appEvents.off(
            "shared-edit-on-post",
            this,
            this._handleSharedEditOnPost
          );
        }

        _handleSharedEditOnPost(post) {
          // eslint-disable-next-line no-console
          console.log("[Topic Controller] Handling shared-edit-on-post event", {
            postId: post.get("id"),
            draftKey: post.get("topic.draft_key"),
            draftSequence: post.get("topic.draft_sequence"),
          });
          const draftKey = post.get("topic.draft_key");
          const draftSequence = post.get("topic.draft_sequence");

          this.get("composer").open({
            post,
            action: SHARED_EDIT_ACTION,
            draftKey,
            draftSequence,
          });
        }
      }
  );
}

function customizePostMenu(api) {
  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { post, buttonLabels, buttonKeys } }) => {
      if (!post.shared_edits_enabled || !post.canEdit) {
        return;
      }

      dag.replace(buttonKeys.EDIT, SharedEditButton, {
        after: [buttonKeys.SHOW_MORE, buttonKeys.REPLY],
      });
      dag.reposition(buttonKeys.REPLY, {
        after: buttonKeys.SHOW_MORE,
        before: buttonKeys.EDIT,
      });

      buttonLabels.hide(buttonKeys.REPLY);
    }
  );

  // register the property as tracked to ensure the button is correctly updated
  api.addTrackedPostProperties("shared_edits_enabled");
}

export default {
  name: "discourse-shared-edits",
  initialize: (container) => {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.shared_edits_enabled) {
      return;
    }

    withPluginApi(initWithApi);
  },
};
