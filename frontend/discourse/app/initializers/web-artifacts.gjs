import { withPluginApi } from "discourse/lib/plugin-api";
import WebArtifact from "../components/web-artifact";

function initializeWebArtifacts(api) {
  api.decorateCookedElement(
    (element, helper) => {
      if (!helper.renderGlimmer) {
        return;
      }

      const post = helper.getModel?.();
      const editableIds = new Set(post?.editable_web_artifact_ids || []);
      const previewMode = !post;

      [...element.querySelectorAll("div.web-artifact")].forEach(
        (artifactElement) => {
          if (artifactElement.closest("aside.quote")) {
            return;
          }

          const artifactId = artifactElement.getAttribute(
            "data-web-artifact-id"
          );
          const artifactVersion = artifactElement.getAttribute(
            "data-web-artifact-version"
          );
          const artifactHeight = artifactElement.getAttribute(
            "data-web-artifact-height"
          );
          const autorun =
            artifactElement.getAttribute("data-web-artifact-autorun") ||
            artifactElement.hasAttribute("data-web-artifact-autorun");
          const seamless =
            artifactElement.getAttribute("data-web-artifact-seamless") ||
            artifactElement.hasAttribute("data-web-artifact-seamless");

          const canEdit =
            previewMode ||
            (artifactId && editableIds.has(parseInt(artifactId, 10)));

          const dataAttributes = {};
          for (const attr of artifactElement.attributes) {
            if (
              attr.name.startsWith("data-") &&
              !attr.name.match(
                /^data-web-artifact-(id|version|height|autorun|seamless)$/
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
                @canEdit={{canEdit}}
                @previewMode={{previewMode}}
                @dataAttributes={{dataAttributes}}
              />
            </template>
          );
        }
      );
    },
    { id: "web-artifact" }
  );
}

export default {
  name: "web-artifact",
  initialize() {
    withPluginApi(initializeWebArtifacts);
  },
};
