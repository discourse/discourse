export function setup(helper) {
  const opts = helper.getOptions();

  if (opts.previewing && opts.injectLineNumbersToPreview) {
    helper.whiteList([
      "p.preview-sync-line",
      "p[data-line-number]",
      "h1.preview-sync-line",
      "h1[data-line-number]",
      "h2.preview-sync-line",
      "h2[data-line-number]",
      "h3.preview-sync-line",
      "h3[data-line-number]",
      "h4.preview-sync-line",
      "h4[data-line-number]",
      "h5.preview-sync-line",
      "h5[data-line-number]",
      "h6.preview-sync-line",
      "h6[data-line-number]",
      "blockquote.preview-sync-line",
      "blockquote[data-line-number]",
      "hr.preview-sync-line",
      "hr[data-line-number]",
      "ul.preview-sync-line",
      "ul[data-line-number]",
      "ol.preview-sync-line",
      "ol[data-line-number]"
    ]);

    helper.registerPlugin(md => {
      const injectLineNumber = (tokens, index, options, env, self) => {
        let line;
        const token = tokens[index];

        if (token.map && token.level === 0) {
          line = token.map[0];
          token.attrJoin("class", "preview-sync-line");
          token.attrSet("data-line-number", String(line));
        }

        return self.renderToken(tokens, index, options, env, self);
      };

      md.renderer.rules.paragraph_open = injectLineNumber;
      md.renderer.rules.heading_open = injectLineNumber;
      md.renderer.rules.blockquote_open = injectLineNumber;
      md.renderer.rules.hr = injectLineNumber;
      md.renderer.rules.ordered_list_open = injectLineNumber;
      md.renderer.rules.bullet_list_open = injectLineNumber;
    });
  }
}
