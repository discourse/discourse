import MarkdownTabs from "discourse/components/markdown-tabs";
import { withPluginApi } from "discourse/lib/plugin-api";

function initializeMarkdownTabs(api) {
  api.decorateCookedElement(
    (elem, helper) => {
      // no way to decorate so skip
      if (!helper || !helper.renderGlimmer) {
        return;
      }
      for (const tabsElement of [...elem.querySelectorAll(".markdown-tabs")]) {
        const tabs = [...tabsElement.querySelectorAll("section")].map(
          (section) => {
            return {
              title: section.querySelector("h4").textContent.trim(),
              content: section.innerHTML
                .replace(section.querySelector("h4").outerHTML, "")
                .trim(),
              selected: section.hasAttribute("data-selected"),
            };
          }
        );

        while (tabsElement.firstChild) {
          tabsElement.removeChild(tabsElement.firstChild);
        }

        helper.renderGlimmer(tabsElement, <template>
          <MarkdownTabs @tabs={{tabs}} />
        </template>);
      }
    },
    { id: "discourse-tabs", onlyStream: false }
  );
}

export default {
  name: "discourse-tabs",
  initialize() {
    withPluginApi("0.8.7", initializeMarkdownTabs);
  },
};
