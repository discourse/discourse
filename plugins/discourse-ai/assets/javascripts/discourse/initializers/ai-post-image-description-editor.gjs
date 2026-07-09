import { withPluginApi } from "discourse/lib/plugin-api";
import AiPostImageDescriptionEditorButton from "../components/ai-post-image-description-editor-button";
import {
  ensureImageDescriptionTarget,
  imageBase62Sha1,
} from "../lib/post-image-description-editor";

function initializeAiPostImageDescriptionEditor(api) {
  const editor = api.container.lookup("service:post-image-description-editor");

  api.decorateCookedElement(
    (element, helper) => {
      if (
        !helper.renderGlimmer ||
        !element.classList.contains("d-editor-preview")
      ) {
        return;
      }

      if (!editor.canEditCurrentComposer) {
        return;
      }

      editor.ensureLoaded();

      element.querySelectorAll("span.image-wrapper").forEach((imageWrapper) => {
        const image = imageWrapper.querySelector("img");
        const base62Sha1 = imageBase62Sha1(image);

        if (!base62Sha1) {
          return;
        }

        const target = ensureImageDescriptionTarget(imageWrapper);
        if (!target) {
          return;
        }

        helper.renderGlimmer(
          target,
          <template>
            <AiPostImageDescriptionEditorButton @base62Sha1={{base62Sha1}} />
          </template>
        );
      });
    },
    {
      id: "ai-post-image-description-editor",
    }
  );
}

export default {
  name: "ai-post-image-description-editor",
  initialize() {
    withPluginApi(initializeAiPostImageDescriptionEditor);
  },
};
