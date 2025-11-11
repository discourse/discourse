export function setup(helper) {
  helper.allowList(["span.spoiler", "div.spoiler"]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features["spoiler-alert"] = !!siteSettings.spoiler_enabled;
  });

  helper.registerPlugin((md) => {
    md.inline.bbcode.ruler.push("spoiler", {
      tag: "spoiler",
      wrap: "span.spoiler",
    });

    md.block.bbcode.ruler.push("spoiler", {
      tag: "spoiler",
      wrap: "div.spoiler",
    });
  });
}
