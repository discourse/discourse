function setupTabs(helper) {
  helper.allowList(["div.markdown-tabs", "section", "section[data-selected]"]);

  helper.registerPlugin((md) => {
    const ruler = md.block.bbcode.ruler;

    ruler.push("tabs", {
      tag: "tabs",
      before(state) {
        state.env.tabContent = [];

        const token = state.push("tab_open", "div", 1);
        token.attrs = [["class", "markdown-tabs"]];
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

          state.env.tabContent.forEach((tab) => {
            const section = state.push("tab_panel_open", "section", 1);
            if (tab.selected) {
              section.attrs = [["data-selected", ""]];
            }

            state.push("tab_header_open", "h4", 1);
            const textToken = state.push("text", "", 0);
            textToken.content = tab.name.toString().trim();
            state.push("tab_header_close", "h4", -1);

            tab.content.forEach((token) => state.tokens.push(token));

            state.push("tab_panel_close", "section", -1);
          });
        }

        state.env.tabContent = null;

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
