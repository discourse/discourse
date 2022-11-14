export default function deprecated(msg, opts = {}) {
  msg = ["Deprecation notice:", msg];
  if (opts.since) {
    msg.push(`(deprecated since Discourse ${opts.since})`);
  }
  if (opts.dropFrom) {
    msg.push(`(removal in Discourse ${opts.dropFrom})`);
  }
  msg = msg.join(" ");

  if (opts.raiseError) {
    throw msg;
  }

  let consolePrefix = "";
  if (window.Discourse) {
    // This module doesn't exist in pretty-text/wizard/etc.
    consolePrefix =
      require("discourse/lib/source-identifier").consolePrefix() || "";
  }

  console.warn(consolePrefix, msg); //eslint-disable-line no-console
}
