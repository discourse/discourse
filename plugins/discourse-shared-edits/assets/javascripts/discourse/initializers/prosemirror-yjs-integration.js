import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "prosemirror-yjs-integration",
  initialize() {
    withPluginApi((api) => {
      // eslint-disable-next-line no-console
      console.log("[YJS Integration] Initializing ProseMirror YJS integration");

      // Listen for ProseMirror ready event
      // Shared edits only work in rich mode (mode switching is disabled)
      api.onAppEvent(
        "composer:prosemirror-ready",
        ({ view, convertToMarkdown }) => {
          // Get the composer and check if this is a shared edit
          const composer = api.container.lookup("service:composer");
          const postId = composer?.model?.sharedEditPostId;

          // eslint-disable-next-line no-console
          console.log("[YJS Integration] ProseMirror ready", {
            hasView: !!view,
            postId,
            isSharedEdit: !!postId,
          });

          const yjsManager = api.container.lookup(
            "service:yjs-prosemirror-manager"
          );

          if (yjsManager && postId) {
            yjsManager.subscribe(view, postId, convertToMarkdown);
          }
        }
      );
    });
  },
};
