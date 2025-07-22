import { withPluginApi } from "discourse/lib/plugin-api";
import AiArtifact from "../discourse/components/ai-artifact";

function initializeAiArtifacts(api) {
  api.decorateCookedElement(
    (element, helper) => {
      if (!helper.renderGlimmer) {
        return;
      }

      [...element.querySelectorAll("div.ai-artifact")].forEach(
        (artifactElement) => {
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
                @dataAttributes={{dataAttributes}}
              />
            </template>
          );
        }
      );
    },
    {
      id: "ai-artifact",
      onlyStream: true,
    }
  );
}

export default {
  name: "ai-artifact",
  initialize() {
    withPluginApi("0.8.7", initializeAiArtifacts);
  },
};
