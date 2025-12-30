import { withPluginApi } from "discourse/lib/plugin-api";
import {
  buildDiscourseMathOptions,
  renderMathInElement,
} from "../lib/math-renderer";

function initializeMath(api, options) {
  const provider = options.provider;

  api.decorateCookedElement(
    (element) => renderMathInElement(element, options),
    { id: provider }
  );

  api.decorateChatMessage((element) => renderMathInElement(element, options), {
    id: `${provider}-chat`,
  });
}

export default {
  name: "apply-math",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const options = buildDiscourseMathOptions(siteSettings);

    if (!options.enabled) {
      return;
    }

    withPluginApi((api) => initializeMath(api, options));
  },
};
