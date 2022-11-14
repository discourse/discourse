const handlers = [];
const disabledDeprecations = new Set();

export default function deprecated(msg, opts = {}) {
  if (opts.id && disabledDeprecations.has(opts.id)) {
    return;
  }

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

  handlers.forEach((h) => h(msg, opts));
}

export function registerDeprecationHandler(callback) {
  handlers.push(callback);
}

export async function withSilencedDeprecations(deprecationIds, callback) {
  try {
    Array(deprecationIds).forEach((id) => disabledDeprecations.add(id));
    return await callback();
  } finally {
    Array(deprecationIds).forEach((id) => disabledDeprecations.delete(id));
  }
}
