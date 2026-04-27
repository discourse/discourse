import { withPluginApi } from "discourse/lib/plugin-api";
import AiArtifact from "../components/ai-artifact";

function initializeAiArtifacts(api) {
  api.decorateCookedElement(
    (element, helper) => {
      if (!helper.renderGlimmer) {
        return;
      }

      const post = helper.getModel?.();
      const editableIds = new Set(post?.editable_ai_artifact_ids || []);
      const previewMode = !post;

      [...element.querySelectorAll("div.ai-artifact")].forEach(
        (artifactElement) => {
          if (artifactElement.closest("aside.quote")) {
            return;
          }

          const artifactId = artifactElement.getAttribute(
            "data-ai-artifact-id"
          );

          const artifactVersion = artifactElement.getAttribute(
            "data-ai-artifact-version"
          );

          const artifactHeight = artifactElement.getAttribute(
            "data-ai-artifact-height"
          );

          const autorun =
            artifactElement.getAttribute("data-ai-artifact-autorun") ||
            artifactElement.hasAttribute("data-ai-artifact-autorun");

          const seamless =
            artifactElement.getAttribute("data-ai-artifact-seamless") ||
            artifactElement.hasAttribute("data-ai-artifact-seamless");

          const canEdit =
            previewMode ||
            (artifactId && editableIds.has(parseInt(artifactId, 10)));

          const dataAttributes = {};
          for (const attr of artifactElement.attributes) {
            if (
              attr.name.startsWith("data-") &&
              attr.name !== "data-ai-artifact-id" &&
              attr.name !== "data-ai-artifact-version" &&
              attr.name !== "data-ai-artifact-height" &&
              attr.name !== "data-ai-artifact-autorun" &&
              attr.name !== "data-ai-artifact-seamless"
            ) {
              dataAttributes[attr.name] = attr.value;
            }
          }

          helper.renderGlimmer(
            artifactElement,
            <template>
              <AiArtifact
                @artifactId={{artifactId}}
                @artifactVersion={{artifactVersion}}
                @artifactHeight={{artifactHeight}}
                @autorun={{autorun}}
                @seamless={{seamless}}
                @canEdit={{canEdit}}
                @previewMode={{previewMode}}
                @dataAttributes={{dataAttributes}}
              />
            </template>
          );
        }
      );
    },
    { id: "ai-artifact" }
  );
}

export default {
  name: "ai-artifact",
  initialize() {
    withPluginApi(initializeAiArtifacts);
  },
};
