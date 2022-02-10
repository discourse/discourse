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

  // Using deferred `require` because this is discourse-specific logic which
  // we don't want to run in pretty-text/wizard/etc.
  const consolePrefix =
    require("discourse/lib/source-identifier")?.consolePrefix() || "";

  console.warn(consolePrefix, msg); //eslint-disable-line no-console
}
