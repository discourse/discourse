import { withPluginApi } from "discourse/lib/plugin-api";

function initializeMarkdownTabs(api) {
  api.decorateCooked(
    ($elem) => {
      const tabs = $elem[0].querySelectorAll(".markdown-tabs");
      if (!tabs.length) {
        return;
      }

      tabs.forEach((tabContainer) => {
        const tabButtons = tabContainer.querySelectorAll(".markdown-tab");
        const panels = tabContainer.querySelectorAll(".markdown-tab-panel");

        tabButtons.forEach((tab) => {
          tab.addEventListener("click", (e) => {
            e.preventDefault();

            if (tab.hasAttribute("data-selected")) {
              return;
            }

            const tabId = tab.getAttribute("data-tab-id");

            // Remove selected state from all tabs and panels
            tabButtons.forEach((t) => t.removeAttribute("data-selected"));
            panels.forEach((p) => p.removeAttribute("data-selected"));

            // Set selected state for clicked tab and its panel
            tab.setAttribute("data-selected", "");
            const panel = tabContainer.querySelector(
              `.markdown-tab-panel[data-tab-id="${tabId}"]`
            );
            if (panel) {
              panel.setAttribute("data-selected", "");
            }
          });
        });
      });
    },
    { id: "discourse-tabs" }
  );
}

export default {
  name: "discourse-tabs",
  initialize() {
    withPluginApi("0.8.7", initializeMarkdownTabs);
  },
};
