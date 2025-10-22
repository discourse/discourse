export function setup(helper) {
  if (!helper.markdownIt) {
    return;
  }

  helper.allowList([
    "div.graphviz",
    "div.graphviz.is-loading",
    "div.graphviz-svg",
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.graphviz = siteSettings.discourse_graphviz_enabled;
  });

  helper.registerPlugin((md) => {
    if (md.options.discourse.features.graphviz) {
      md.block.bbcode.ruler.push("graphviz", {
        tag: "graphviz",

        replace(state, tagInfo, content) {
          const engines = ["dot", "neato", "circo", "fdp", "osage", "twopi"];
          const token = state.push("html_raw", "", 0);

          const escaped = state.md.utils.escapeHtml(content);
          const inputEngine = state.md.utils.escapeHtml(tagInfo.attrs.engine);
          const engine = engines.includes(inputEngine)
            ? `data-engine='${inputEngine}'`
            : "data-engine='dot'";

          let svgOnly = "";
          if (tagInfo.attrs.svg === "true") {
            svgOnly = " graphviz-svg";
          } else if (tagInfo.attrs.svg === "false") {
            svgOnly = " graphviz-no-svg";
          }

          token.content = `<div class="graphviz is-loading${svgOnly}" ${engine}>\n${escaped}\n</div>\n`;

          return true;
        },
      });
    }
  });
}
