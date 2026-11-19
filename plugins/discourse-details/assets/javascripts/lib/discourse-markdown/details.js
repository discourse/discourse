import { i18n } from "discourse-i18n";

const rule = {
  tag: "details",
  before(state, tagInfo) {
    const attrs = tagInfo.attrs;
    const details = state.push("bbcode_open", "details", 1);
    state.push("bbcode_open", "summary", 1);

    if (attrs.open === "") {
      details.attrs = [["open", ""]];
    }

    const token = state.push("text", "", 0);
    token.content = attrs["_default"] || "";
    if (attrs.ai === "") {
      details.attrSet("class", "ai-quote");
      token.meta = { detailsAiSummary: true };
    }

    state.push("bbcode_close", "summary", -1);
  },

  after(state) {
    state.push("bbcode_close", "details", -1);
  },
};

export function setup(helper) {
  helper.allowList([
    "summary",
    "summary[title]",
    "details",
    "details[open]",
    "details.ai-quote",
    "details[data-ai-generated=true]",
    "details.elided",
  ]);

  helper.registerPlugin((md) => {
    md.block.bbcode.ruler.push("details", rule);
    const renderText = md.renderer.rules.text;
    md.renderer.rules.text = (tokens, idx, options, env, slf) => {
      const summary = renderText(tokens, idx, options, env, slf);
      if (!tokens[idx].meta?.detailsAiSummary) {
        return summary;
      }

      const label = md.utils.escapeHtml(i18n("post.ai_generated"));
      const title = md.utils.escapeHtml(i18n("post.ai_generated_title"));
      return `<span>${summary}</span><span class="ai-badge" data-ai-label="${label}" title="${title}"></span>`;
    };
  });
}
