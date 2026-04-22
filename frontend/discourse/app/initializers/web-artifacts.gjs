import { withPluginApi } from "discourse/lib/plugin-api";
import WebArtifact from "../components/web-artifact";

function initializeWebArtifacts(api) {
  api.decorateCookedElement(
    (element, helper) => {
      if (!helper.renderGlimmer) {
        return;
      }

      [
        ...element.querySelectorAll("div.ai-artifact, div.web-artifact"),
      ].forEach((artifactElement) => {
        const artifactId =
          artifactElement.getAttribute("data-web-artifact-id") ||
          artifactElement.getAttribute("data-ai-artifact-id");

        const artifactVersion =
          artifactElement.getAttribute("data-web-artifact-version") ||
          artifactElement.getAttribute("data-ai-artifact-version");

        const artifactHeight =
          artifactElement.getAttribute("data-web-artifact-height") ||
          artifactElement.getAttribute("data-ai-artifact-height");

        const autorun =
          artifactElement.getAttribute("data-web-artifact-autorun") ||
          artifactElement.getAttribute("data-ai-artifact-autorun") ||
          artifactElement.hasAttribute("data-web-artifact-autorun") ||
          artifactElement.hasAttribute("data-ai-artifact-autorun");

        const seamless =
          artifactElement.getAttribute("data-web-artifact-seamless") ||
          artifactElement.getAttribute("data-ai-artifact-seamless") ||
          artifactElement.hasAttribute("data-web-artifact-seamless") ||
          artifactElement.hasAttribute("data-ai-artifact-seamless");

        const dataAttributes = {};
        for (const attr of artifactElement.attributes) {
          if (
            attr.name.startsWith("data-") &&
            !attr.name.match(
              /^data-(web|ai)-artifact-(id|version|height|autorun|seamless)$/
            )
          ) {
            dataAttributes[attr.name] = attr.value;
          }
        }

        helper.renderGlimmer(
          artifactElement,
          <template>
            <WebArtifact
              @artifactId={{artifactId}}
              @artifactVersion={{artifactVersion}}
              @artifactHeight={{artifactHeight}}
              @autorun={{autorun}}
              @seamless={{seamless}}
              @dataAttributes={{dataAttributes}}
            />
          </template>
        );
      });
    },
    {
      id: "web-artifact",
      onlyStream: true,
    }
  );
}

export default {
  name: "web-artifact",
  initialize() {
    withPluginApi(initializeWebArtifacts);
  },
};
