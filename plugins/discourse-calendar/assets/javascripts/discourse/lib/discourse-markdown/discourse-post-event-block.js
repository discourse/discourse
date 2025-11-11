const rule = {
  tag: "event",

  wrap(token, info) {
    if (!info.attrs.start) {
      return false;
    }

    token.attrs = [["class", "discourse-post-event"]];

    Object.keys(info.attrs).forEach((key) => {
      const value = info.attrs[key];

      if (typeof value !== "undefined") {
        token.attrs.push([`data-${dasherize(key)}`, value]);
      }
    });

    return true;
  },
};

function dasherize(input) {
  return input.replace(/[A-Z]/g, function (char, index) {
    return (index !== 0 ? "-" : "") + char.toLowerCase();
  });
}

export function setup(helper) {
  helper.allowList(["div.discourse-post-event"]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.discourse_post_event =
      siteSettings.calendar_enabled &&
      siteSettings.discourse_post_event_enabled;
  });

  helper.registerPlugin((md) =>
    md.block.bbcode.ruler.push("discourse-post-event", rule)
  );
}
