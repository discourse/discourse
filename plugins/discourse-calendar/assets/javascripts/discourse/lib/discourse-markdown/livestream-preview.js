function setupMarkdownIt(helper) {
  helper.registerOptions((opts) => {
    opts.features["livestream-preview"] = true;
  });

  helper.registerPlugin((md) => {
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
