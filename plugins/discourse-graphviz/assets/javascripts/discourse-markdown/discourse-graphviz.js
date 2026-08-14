const ENGINES = ["dot", "neato", "circo", "fdp", "osage", "twopi"];

export function setup(helper) {
  if (!helper.markdownIt) {
    return;
  }

  helper.allowList([
    "div.graphviz",
    "div[class=graphviz is-loading]",
    "div[data-engine]",
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.graphviz = siteSettings.discourse_graphviz_enabled;
  });

  helper.registerPlugin((md) => {
    if (!md.options.discourse.features.graphviz) {
      return;
    }

    md.block.bbcode.ruler.push("graphviz", {
      tag: "graphviz",

      replace(state, tagInfo, content) {
        const token = state.push("graphviz", "div", 0);
        token.block = true;
        token.content = content;
        token.attrs = [
          [
            "data-engine",
            ENGINES.includes(tagInfo.attrs.engine)
              ? tagInfo.attrs.engine
              : "dot",
          ],
        ];

        return true;
      },
    });

    // a single token keeps the graph source out of the token stream as text, so
    // the rich editor can hold it as an attribute of one leaf node
    md.renderer.rules.graphviz = (tokens, idx) => {
      const token = tokens[idx];
      const source = md.utils.escapeHtml(token.content);
      const engine = md.utils.escapeHtml(token.attrGet("data-engine"));

      return `<div class="graphviz is-loading" data-engine="${engine}">\n${source}\n</div>\n`;
    };
  });
}
