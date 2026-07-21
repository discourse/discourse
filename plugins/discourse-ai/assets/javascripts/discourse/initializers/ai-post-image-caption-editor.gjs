import { withPluginApi } from "discourse/lib/plugin-api";
import AiPostImageCaptionEditorButton from "../components/ai-post-image-caption-editor-button";
import {
  ensureImageCaptionTarget,
  imageBase62Sha1,
} from "../lib/post-image-caption-editor";

function initializeAiPostImageCaptionEditor(api) {
  const editor = api.container.lookup("service:post-image-caption-editor");

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

        const target = ensureImageCaptionTarget(imageWrapper);
        if (!target) {
          return;
        }

        helper.renderGlimmer(
          target,
          <template>
            <AiPostImageCaptionEditorButton @base62Sha1={{base62Sha1}} />
          </template>
        );
      });
    },
    {
      id: "ai-post-image-caption-editor",
    }
  );
}

export default {
  name: "ai-post-image-caption-editor",
  initialize() {
    withPluginApi(initializeAiPostImageCaptionEditor);
  },
};
