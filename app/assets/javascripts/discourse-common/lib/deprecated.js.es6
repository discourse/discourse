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
  console.warn(msg); // eslint-disable-line no-console
}
