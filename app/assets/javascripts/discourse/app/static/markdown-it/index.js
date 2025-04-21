import { htmlSafe } from "@ember/template";
import DiscourseMarkdownIt from "discourse-markdown-it";
import loadPluginFeatures from "./features";
import MentionsParser from "./mentions-parser";
import buildOptions from "./options";

export function buildEngine(options) {
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
