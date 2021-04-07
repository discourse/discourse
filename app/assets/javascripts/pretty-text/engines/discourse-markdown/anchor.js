export function setup(helper) {
  helper.registerPlugin((md) => {
    md.core.ruler.push("anchor", (state) => {
      for (let idx = 0; idx < state.tokens.length; idx++) {
        if (state.tokens[idx].type !== "heading_open") {
          continue;
        }

        const linkOpen = new state.Token("link_open", "a", 1);
        const linkClose = new state.Token("link_close", "a", -1);

        const slug = state.tokens[idx + 1].content
          .toLowerCase()
          .replace(/\s+/g, "-")
          .replace(/[^\w\-]+/g, "")
          .replace(/\-\-+/g, "-")
          .replace(/^-+/, "")
          .replace(/-+$/, "");

        linkOpen.attrSet("name", slug);
        linkOpen.attrSet("class", "anchor");
        linkOpen.attrSet("href", "#" + slug);

        state.tokens[idx + 1].children.unshift(linkClose);
        state.tokens[idx + 1].children.unshift(linkOpen);
      }
    });
  });
}
