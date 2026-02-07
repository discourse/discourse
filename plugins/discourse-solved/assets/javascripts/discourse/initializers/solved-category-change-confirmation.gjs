import { action } from "@ember/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import Category from "discourse/models/category";
import CategoryChangeSolvedConfirmationModal from "../components/modal/category-change-solved-confirmation";

const STORAGE_KEY = "discourse-solved-hide-category-change-confirmation";

export default {
  name: "solved-category-change-confirmation",

  initialize() {
    withPluginApi((api) => {
      api.modifyClass(
        "controller:topic",
        (Superclass) =>
          class extends Superclass {
            @action
            async finishedEditingTopic() {
              if (!this.editingTopic) {
                return;
              }

              let isSolved = (id) =>
                Category.findById(id)?.enable_accepted_answers;

              const props = this.get("buffered.buffer");
              let solvedStateChanged = false;

              if (
                props.category_id !== undefined &&
                !this.siteSettings.allow_solved_on_all_topics
              ) {
                const oldSolved = isSolved(this.model.category_id);
                const newSolved = isSolved(props.category_id);

                solvedStateChanged = oldSolved !== newSolved;

                if (this.model.accepted_answer && oldSolved && !newSolved) {
                  const showConfirmation =
                    localStorage.getItem(STORAGE_KEY) !== "true";

                  if (showConfirmation) {
                    const result = await this.modal.show(
                      CategoryChangeSolvedConfirmationModal
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

              await super.finishedEditingTopic();

              if (solvedStateChanged) {
                this.model.postStream.refresh({ forceLoad: true });
              }
            }
          }
      );
    });
  },
};
