import { service } from "@ember/service";
import { withPluginApi } from "discourse/lib/plugin-api";

const SHARED_EDIT_ACTION = "sharedEdit";

export default {
  name: "discourse-shared-edits-composer-service",

  initialize: (container) => {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.shared_edits_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.modifyClass(
        "service:composer",
        (Superclass) =>
          class extends Superclass {
            @service yjsSharedEditManager;
            @service yjsProsemirrorManager;

            async open(opts) {
              // eslint-disable-next-line no-console
              console.log("[Composer Service] Open called", {
                action: opts.action,
                isSharedEdit: opts.action === SHARED_EDIT_ACTION,
                postId: opts.post?.id,
              });

              // Set sharedEditPostId BEFORE calling super.open
              // This ensures it's available when DEditor initializes
              if (opts.action === SHARED_EDIT_ACTION && opts.post?.id) {
                // Force rich editor mode for shared edits
                opts.forceEditorMode = "rich";

                // Set it on opts so it gets passed through
                if (!this.model) {
                  // Model not created yet, will be set by super.open
                  opts.sharedEditPostId = opts.post.id;
                } else {
                  this.model.set("sharedEditPostId", opts.post.id);
                }
              }

              await super.open(...arguments);

              // Ensure it's set after open too
              if (opts.action === SHARED_EDIT_ACTION && opts.post?.id) {
                this.model.set("sharedEditPostId", opts.post.id);
                // eslint-disable-next-line no-console
                console.log(
                  "[Composer Service] Shared edit mode - YJS will be initialized by editor",
                  {
                    postId: opts.post.id,
                    modelPostId: this.model.sharedEditPostId,
                  }
                );
              }
            }

            collapse() {
              // eslint-disable-next-line no-console
              console.log("[Composer Service] Collapse called", {
                action: this.model?.action,
                isSharedEdit: this.model?.action === SHARED_EDIT_ACTION,
              });
              if (this.model?.action === SHARED_EDIT_ACTION) {
                return this.close();
              }
              return super.collapse(...arguments);
            }

            close() {
              // eslint-disable-next-line no-console
              console.log("[Composer Service] Close called", {
                action: this.model?.action,
                isSharedEdit: this.model?.action === SHARED_EDIT_ACTION,
                pmActive: this.yjsProsemirrorManager.isActive,
                textActive: this.yjsSharedEditManager.isActive,
              });
              if (this.model?.action === SHARED_EDIT_ACTION) {
                // eslint-disable-next-line no-console
                console.log("[Composer Service] Committing YJS shared edit");

                // Commit from whichever manager is active
                if (this.yjsProsemirrorManager.isActive) {
                  // eslint-disable-next-line no-console
                  console.log("[Composer Service] Using ProseMirror manager");
                  this.yjsProsemirrorManager.commit();
                } else if (this.yjsSharedEditManager.isActive) {
                  // eslint-disable-next-line no-console
                  console.log("[Composer Service] Using text manager");
                  this.yjsSharedEditManager.commit();
                }
              }
              return super.close(...arguments);
            }

            save() {
              // eslint-disable-next-line no-console
              console.log("[Composer Service] Save called", {
                action: this.model?.action,
                isSharedEdit: this.model?.action === SHARED_EDIT_ACTION,
              });
              if (this.model?.action === SHARED_EDIT_ACTION) {
                return this.close();
              }
              return super.save(...arguments);
            }

            _saveDraft() {
              if (this.model?.action === SHARED_EDIT_ACTION) {
                // eslint-disable-next-line no-console
                console.log(
                  "[Composer Service] Draft save skipped for shared edit"
                );
                return;
              }
              return super._saveDraft(...arguments);
            }
          }
      );
    });
  },
};
