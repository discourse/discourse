import { htmlSafe } from "@ember/template";
import { importSync } from "@embroider/macros";
import loaderShim from "discourse-common/lib/loader-shim";
import DiscourseMarkdownIt from "discourse-markdown-it";
import loadPluginFeatures from "./features";
import MentionsParser from "./mentions-parser";
import buildOptions from "./options";

// Shims the `parseBBCodeTag` utility function back to its old location. For
// now, there is no deprecation with this as we don't have a new location for
// them to import from (well, we do, but we don't want to expose the new code
// to loader.js and we want to make sure the code is loaded lazily).
//
// TODO: find a new home for this – the code is rather small so we could just
// throw it into the synchronous pretty-text package and call it good, but we
// should probably look into why plugins are needing to call this utility in
// the first place, and provide better infrastructure for registering bbcode
// additions instead.
loaderShim("pretty-text/engines/discourse-markdown/bbcode-block", () =>
  importSync("./parse-bbcode-tag")
);

function buildEngine(options) {
  return DiscourseMarkdownIt.withCustomFeatures(
    loadPluginFeatures()
  ).withOptions(buildOptions(options));
}

// Use this to easily create an instance with proper options
export function cook(text, options) {
  return htmlSafe(buildEngine(options).cook(text));
}

// Warm up the engine with a set of options and return a function
// which can be used to cook without rebuilding the engine every time
export function generateCookFunction(options) {
  const engine = buildEngine(options);
  return (text) => engine.cook(text);
}

export function generateLinkifyFunction(options) {
  const engine = buildEngine(options);
  return engine.linkify;
}

export function sanitize(text, options) {
  const engine = buildEngine(options);
  return engine.sanitize(text);
}

export function parse(md, options = {}, env = {}) {
  const engine = buildEngine(options);
  return engine.parse(md, env);
}

export function parseMentions(markdown, options) {
  const engine = buildEngine(options);
  const mentionsParser = new MentionsParser(engine);
  return mentionsParser.parse(markdown);
}
