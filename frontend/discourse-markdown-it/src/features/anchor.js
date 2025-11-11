export function setup(helper) {
  if (helper.getOptions().previewing) {
    return;
  }

  helper.registerPlugin((md) => {
    md.core.ruler.push("anchor", (state) => {
      const postId = helper.getOptions().postId;

      for (
        let idx = 0, lvl = 0, headingId = 0;
        idx < state.tokens.length;
        idx++
      ) {
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

        if (slug.match(/^[^a-z]/)) {
          slug = `h-${slug}`;
        }

        slug = `${slug || "h"}-${++headingId}`;

        if (postId) {
          slug = `p-${postId}-${slug}`;
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
