Discourse.BlockedUrls = {
  blockUrl: function(text) {
    var blockRegexp,
        blocked = Discourse.SiteSettings.blocked_urls;

    if (blocked && blocked.length) {
      if (!blockRegexp) {
        var split = blocked.split("|");
        if (split && split.length) {
          blockRegexp = new RegExp(split.map(function (t) { return "\\]\\([^\\)]*" + t.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&') + "[^\\)]*\\)"; }).join("|"), "ig");
        }
      }
      if (blockRegexp) {
        text = text.replace(blockRegexp, "]()");
      }
    }
    return text;
  }
};
