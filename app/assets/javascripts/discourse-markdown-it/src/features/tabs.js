const WRAP_CLASS = "markdown-tabs";

function setupTabs(helper) {
  helper.allowList([
    "div.markdown-tabs",
    "div.markdown-tabs-wrapper",
    "div.markdown-tab",
    "div.markdown-tab-panels",
    "div.markdown-tab-panel",
    "a[data-tab-id]",
    "div[data-tab-id]",
    "div[data-selected]",
  ]);

  helper.registerPlugin((md) => {
    const ruler = md.block.bbcode.ruler;

    ruler.push("tabs", {
      tag: "tabs",
      before(state) {
        state.env.tabContent = [];

        const token = state.push("tab_open", "div", 1);
        token.attrs = [["class", WRAP_CLASS]];

        const wrapperToken = state.push("tab_wrapper_open", "div", 1);
        wrapperToken.attrs = [["class", "markdown-tabs-wrapper"]];
      },

      after(state) {
        if (state.env.tabContent) {
          // force selection of 1 tab only
          let selected = false;
          state.env.tabContent.forEach((tab) => {
            if (tab.selected) {
              if (selected) {
                tab.selected = false;
              } else {
                selected = true;
              }
            }
          });
          if (!selected) {
            state.env.tabContent[0].selected = true;
          }

          let index = 0;
          state.env.tabContent.forEach((tab) => {
            const tabId = `tab-${index}`;
            index++;

            tab.id = tabId;

            const tabToken = state.push("tab_button_open", "div", 1);
            tabToken.attrs = [
              ["class", "markdown-tab"],
              ["data-tab-id", tabId],
            ];
            if (tab.selected) {
              tabToken.attrs.push(["data-selected", ""]);
            }

            const linkToken = state.push("tab_link_open", "a", 1);
            linkToken.attrs = [["data-tab-id", tabId]];

            // Add tab name
            const textToken = state.push("text", "", 0);
            textToken.content = tab.name;

            state.push("tab_link_close", "a", -1);
            state.push("tab_button_close", "div", -1);
          });
        }

        state.push("tab_wrapper_close", "div", -1);
        state.push("panels_open", "div", 1).attrs = [
          ["class", "markdown-tab-panels"],
        ];

        if (state.env.tabContent) {
          state.env.tabContent.forEach((tab) => {
            const panelToken = state.push("tab_panel_open", "div", 1);
            panelToken.attrs = [
              ["class", "markdown-tab-panel"],
              ["data-tab-id", tab.id],
            ];
            if (tab.selected) {
              panelToken.attrs.push(["data-selected", ""]);
            }

            if (tab.content) {
              tab.content.forEach((token) => state.tokens.push(token));
            }

            state.push("tab_panel_close", "div", -1);
          });
        }

        state.env.tabContent = null;

        state.push("panels_close", "div", -1);
        state.push("tab_close", "div", -1);
      },
    });

    ruler.push("tab", {
      tag: "tab",
      replace(state, tagInfo, content) {
        const attrs = tagInfo.attrs;
        const name = attrs.name || attrs._default || "";
        const selected = attrs.selected === "" || attrs.selected === "true";

        const tokens = [];
        state.md.block.parse(content, state.md, state.env, tokens);

        state.env.tabContent.push({
          selected,
          name,
          content: tokens,
          startPos: state.tokens.length,
        });

        return true;
      },
    });
  });
}

export function setup(helper) {
  setupTabs(helper);
}
