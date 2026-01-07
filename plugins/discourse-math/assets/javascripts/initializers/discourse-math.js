import { apiInitializer } from "discourse/lib/api";
import MathInsertModal from "discourse/plugins/discourse-math/discourse/components/modal/math-insert";
import {
  buildDiscourseMathOptions,
  renderMathInElement,
} from "../lib/math-renderer";

function isAtLineStart(pre) {
  if (!pre) {
    return true;
  }
  const lastNewlineIndex = pre.lastIndexOf("\n");
  const textAfterNewline =
    lastNewlineIndex === -1 ? pre : pre.slice(lastNewlineIndex + 1);
  return textAfterNewline.trim() === "";
}

function initializeMath(api, options) {
  const provider = options.provider;

  api.decorateCookedElement(
    (element) => renderMathInElement(element, options),
    { id: provider }
  );

  if (api.decorateChatMessage) {
    api.decorateChatMessage(
      (element) => renderMathInElement(element, options),
      {
        id: `${provider}-chat`,
      }
    );
  }

  const modal = api.container.lookup("service:modal");

  api.addComposerToolbarPopupMenuOption({
    name: "insert-math",
    label: "discourse_math.composer.insert_math",
    icon: "square-root-variable",
    shortcut: "Shift+M",
    action: (toolbarEvent) => {
      const isBlock = isAtLineStart(toolbarEvent.selected.pre);

      modal.show(MathInsertModal, {
        model: {
          isBlock,
          onInsert: (text, insertAsBlock) => {
            if (insertAsBlock) {
              toolbarEvent.addText(`$$\n${text}\n$$\n`);
            } else {
              toolbarEvent.addText(`$${text}$`);
            }
          },
        },
      });
    },
  });
}

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  const options = buildDiscourseMathOptions(siteSettings);

  if (!options.enabled) {
    return;
  }

  initializeMath(api, options);
});
