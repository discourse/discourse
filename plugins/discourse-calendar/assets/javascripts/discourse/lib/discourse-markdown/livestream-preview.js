function setupMarkdownIt(helper) {
  helper.registerOptions((opts, siteSettings) => {
    opts.features["livestream-preview"] = !!siteSettings.livestream_enabled;
  });

  helper.registerPlugin((md) => {
    // Gated on livestream_enabled so that when it is disabled the standalone
    // discourse-livestream plugin (if installed) owns these bbcode tags
    // instead, avoiding duplicate registration.
    if (!md.options.discourse.features["livestream-preview"]) {
      return;
    }

    md.inline.bbcode.ruler.push("preview", {
      tag: "preview",
      wrap: "span.preview",
    });

    md.block.bbcode.ruler.push("preview", {
      tag: "preview",
      wrap: "div.preview",
    });

    md.inline.bbcode.ruler.push("hidden", {
      tag: "hidden",
      wrap: "span.hidden",
    });

    md.block.bbcode.ruler.push("hidden", {
      tag: "hidden",
      wrap: "div.hidden",
    });
  });
}

export function setup(helper) {
  helper.allowList([
    "span.preview",
    "div.preview",
    "span.hidden",
    "div.hidden",
  ]);

  if (helper.markdownIt) {
    setupMarkdownIt(helper);
  }
}
