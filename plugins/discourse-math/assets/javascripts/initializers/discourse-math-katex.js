import { withPluginApi } from "discourse/lib/plugin-api";
import {
  buildDiscourseMathOptions,
  renderMathInElement,
} from "../lib/math-renderer";

function initializeMath(api, discourseMathOptions) {
  api.decorateCookedElement(
    function (elem) {
      renderMathInElement(elem, discourseMathOptions);
    },
    { id: "katex" }
  );

  if (api.decorateChatMessage) {
    api.decorateChatMessage(
      (element) => {
        renderMathInElement(element, discourseMathOptions);
      },
      { id: "katex-chat" }
    );
  }
}

export default {
  name: "apply-math-katex",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const discourseMathOptions = buildDiscourseMathOptions(siteSettings);
    if (
      discourseMathOptions.enabled &&
      discourseMathOptions.provider === "katex"
    ) {
      withPluginApi(function (api) {
        initializeMath(api, discourseMathOptions);
      });
    }
  },
};
