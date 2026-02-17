import { action } from "@ember/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import Category from "discourse/models/category";
import SolvedRemovalConfirmationModal from "../components/modal/solved-removal-confirmation";

const STORAGE_KEY = "discourse-solved-hide-category-change-confirmation";

export default {
  name: "solved-category-change-confirmation",

  initialize() {
    withPluginApi((api) => {
      api.modifyClass(
        "controller:topic",
        (Superclass) =>
          class extends Superclass {
            _solvedEnabled(categoryId, tags) {
              if (
                this.siteSettings.allow_solved_on_all_topics ||
                Category.findById(categoryId)?.enable_accepted_answers
              ) {
                return true;
              }

              const solvedTags = this.siteSettings.enable_solved_tags
                .split("|")
                .filter(Boolean);

              return tags.some((t) => solvedTags.includes(t.name));
            }

            @action
            async finishedEditingTopic() {
              if (!this.editingTopic) {
                return;
              }

              const props = this.get("buffered.buffer");
              let solvedStateChanged = false;

              if ("category_id" in props || "tags" in props) {
                const oldCategoryId = this.model.category_id;
                const newCategoryId = props.category_id ?? oldCategoryId;
                const oldTags = this.model.tags;
                const newTags = props.tags ?? oldTags;

                const oldAllowed = this._solvedEnabled(oldCategoryId, oldTags);
                const newAllowed = this._solvedEnabled(newCategoryId, newTags);

                solvedStateChanged = oldAllowed !== newAllowed;

                if (this.model.accepted_answer && oldAllowed && !newAllowed) {
                  const showConfirmation =
                    localStorage.getItem(STORAGE_KEY) !== "true";

                  if (showConfirmation) {
                    const result = await this.modal.show(
                      SolvedRemovalConfirmationModal
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
