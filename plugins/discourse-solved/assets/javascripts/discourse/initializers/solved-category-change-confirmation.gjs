import { withPluginApi } from "discourse/lib/plugin-api";
import Category from "discourse/models/category";
import SolvedRemovalConfirmationModal from "../components/modal/solved-removal-confirmation";

const STORAGE_KEY = "discourse-solved-hide-category-change-confirmation";

function solvedEnabled(siteSettings, categoryId, tags) {
  if (
    siteSettings.allow_solved_on_all_topics ||
    Category.findById(categoryId)?.custom_fields?.enable_accepted_answers ===
      "true"
  ) {
    return true;
  }

  const solvedTags = siteSettings.enable_solved_tags.split("|").filter(Boolean);

  return tags.some((t) => solvedTags.includes(t.name));
}

export default {
  name: "solved-category-change-confirmation",

  initialize() {
    withPluginApi((api) => {
      api.registerBehaviorTransformer(
        "topic-controller:finished-editing",
        async ({ next, context }) => {
          const siteSettings = api.container.lookup("service:site-settings");
          const modal = api.container.lookup("service:modal");
          const props = context.buffered;
          const model = context.model;
          let solvedStateChanged = false;

          if ("category_id" in props || "tags" in props) {
            const oldCategoryId = model.category_id;
            const newCategoryId = props.category_id ?? oldCategoryId;
            const oldTags = model.tags;
            const newTags = props.tags ?? oldTags;

            const oldAllowed = solvedEnabled(
              siteSettings,
              oldCategoryId,
              oldTags
            );
            const newAllowed = solvedEnabled(
              siteSettings,
              newCategoryId,
              newTags
            );

            solvedStateChanged = oldAllowed !== newAllowed;

            if (model.accepted_answer && oldAllowed && !newAllowed) {
              const showConfirmation =
                localStorage.getItem(STORAGE_KEY) !== "true";

              if (showConfirmation) {
                const result = await modal.show(SolvedRemovalConfirmationModal);

                if (!result?.confirmed) {
                  return;
                }

                if (result.dontShowAgain) {
                  localStorage.setItem(STORAGE_KEY, "true");
                }
              }
            }
          }

          await next();

          if (solvedStateChanged) {
            model.postStream.refresh({ forceLoad: true });
          }
        }
      );
    });
  },
};
