import MoveToTopic from "discourse/components/modal/move-to-topic";
import ModalService from "discourse/services/modal";
import MoveSolutionConfirmationModal from "../components/modal/move-solution-confirmation";

const STORAGE_KEY = "discourse-solved-hide-move-confirmation";

export default {
  name: "solved-move-confirmation",

  before: "inject-discourse-objects",

  initialize() {
    const originalShow = ModalService.prototype.show;

    ModalService.prototype.show = async function (modal, opts) {
      if (modal === MoveToTopic && opts?.model?.selectedPosts) {
        const selectedPosts = opts.model.selectedPosts;
        const solvedPost = selectedPosts?.find((p) => p.accepted_answer);

        if (solvedPost) {
          const hideConfirmation = localStorage.getItem(STORAGE_KEY) === "true";

          if (!hideConfirmation) {
            const result = await originalShow.call(
              this,
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

      return originalShow.call(this, modal, opts);
    };
  },
};
