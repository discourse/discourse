import { withPluginApi } from "discourse/lib/plugin-api";
import MoveSolutionConfirmationModal from "../components/modal/move-solution-confirmation.gjs";

const STORAGE_KEY = "discourse-solved-hide-move-confirmation";

// Core passes an import promise first, then the loaded class.
async function isMoveToTopic(modal) {
  if (typeof modal !== "function") {
    return false;
  }

  const { default: MoveToTopic } =
    await import("discourse/components/modal/move-to-topic");
  return modal === MoveToTopic;
}

export default {
  name: "solved-move-confirmation",

  before: "inject-discourse-objects",

  initialize() {
    withPluginApi((api) => {
      api.modifyClass("service:modal", {
        pluginId: "discourse-solved",

        _solvedOriginalShow: null,

        async show(modal, opts) {
          if (!this._solvedOriginalShow) {
            this._solvedOriginalShow = this._super.bind(this);
          }

          const originalShow = this._solvedOriginalShow;

          const selectedPosts = opts?.model?.selectedPosts;

          if (
            selectedPosts?.some((p) => p.accepted_answer) &&
            localStorage.getItem(STORAGE_KEY) !== "true" &&
            (await isMoveToTopic(modal))
          ) {
            const result = await originalShow(MoveSolutionConfirmationModal, {
              model: { count: selectedPosts.length },
            });

            if (!result?.confirmed) {
              return;
            }

            if (result.dontShowAgain) {
              localStorage.setItem(STORAGE_KEY, "true");
            }
          }

          return originalShow(modal, opts);
        },
      });
    });
  },
};
