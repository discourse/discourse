const SPECIAL_CHARACTERS_REGEX = /[\u2000-\u206F\u2E00-\u2E7F\\'!"#$%&()*+,./:;<=>?@[\]^`{|}~’]/g;

export function setup(helper) {
  if (helper.getOptions().previewing) {
    return;
  }

  helper.registerPlugin((md) => {
    md.core.ruler.push("anchor", (state) => {
      for (let idx = 0, lvl = 0; idx < state.tokens.length; idx++) {
        if (
          state.tokens[idx].type === "blockquote_open" ||
          (state.tokens[idx].type === "bbcode_open" &&
            state.tokens[idx].tag === "aside")
        ) {
          ++lvl;
        } else if (
          state.tokens[idx].type === "blockquote_close" ||
          (state.tokens[idx].type === "bbcode_close" &&
            state.tokens[idx].tag === "aside")
        ) {
          --lvl;
        }

        if (lvl > 0 || state.tokens[idx].type !== "heading_open") {
          continue;
        }

        const linkOpen = new state.Token("link_open", "a", 1);
        const linkClose = new state.Token("link_close", "a", -1);

        let slug = state.tokens[idx + 1].content
          .toLowerCase()
          .replace(/\s+/g, "-")
          .replace(/[^\w\-]+/g, "")
          .replace(/\-\-+/g, "-")
          .replace(/^-+/, "")
          .replace(/-+$/, "");

        if (slug.length === 0) {
          slug = state.tokens[idx + 1].content
            .replace(/\s+/g, "-")
            .replace(SPECIAL_CHARACTERS_REGEX, "")
            .replace(/\-\-+/g, "-")
            .replace(/^-+/, "")
            .replace(/-+$/, "");
          slug = encodeURI(slug).replace(/%/g, "").substr(0, 24);
        }

        linkOpen.attrSet("name", slug);
        linkOpen.attrSet("class", "anchor");
        linkOpen.attrSet("href", "#" + slug);

        state.tokens[idx + 1].children.unshift(linkClose);
        state.tokens[idx + 1].children.unshift(linkOpen);
      }
    });
  });
}
