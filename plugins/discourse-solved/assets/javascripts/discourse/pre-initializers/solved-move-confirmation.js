import MoveToTopic from "discourse/components/modal/move-to-topic";
import { withPluginApi } from "discourse/lib/plugin-api";
import MoveSolutionConfirmationModal from "../components/modal/move-solution-confirmation";

const STORAGE_KEY = "discourse-solved-hide-move-confirmation";

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

          if (modal === MoveToTopic && opts?.model?.selectedPosts) {
            const selectedPosts = opts.model.selectedPosts;
            const hasSolvedPost = selectedPosts?.some((p) => p.accepted_answer);

            if (hasSolvedPost) {
              const hideConfirmation =
                localStorage.getItem(STORAGE_KEY) === "true";

              if (!hideConfirmation) {
                const result = await originalShow(
                  MoveSolutionConfirmationModal,
                  {
                    model: { count: selectedPosts.length },
                  }
                );

                if (!result?.confirmed) {
                  return;
                }

                if (result.dontShowAgain) {
                  localStorage.setItem(STORAGE_KEY, "true");
                }
              }
            }
          }

          return originalShow(modal, opts);
        },
      });
    });
  },
};
