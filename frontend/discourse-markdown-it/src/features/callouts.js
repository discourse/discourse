import { buildEmojiUrl } from "pretty-text/emoji";
import { i18n } from "discourse-i18n";
import { getEmojiTokenByName } from "./emoji";

// Same types as GitHub alerts, each with a default emoji close to GitHub's icon
export const CALLOUT_EMOJIS = {
  note: "information_source",
  tip: "bulb",
  important: "exclamation",
  warning: "warning",
  caution: "stop_sign",
};

const TYPE = `(${Object.keys(CALLOUT_EMOJIS).join("|")})`;
const EMOJI_OPTION = "(?:[ \\t]+emoji=:?([\\w+-]+(?::t[2-6])?):?)?";
const MARKER = `\\[!${TYPE}${EMOJI_OPTION}\\]`;
const MARKER_LINE = new RegExp(`^${MARKER}[ \\t]*(?:\\n|$)`, "i");

export const CALLOUT_MARKER = new RegExp(`^${MARKER}$`, "i");

/**
 * Returns the emoji of a callout title: the custom one when it exists and is
 * allowed, the type's default otherwise.
 *
 * @param {string} type
 * @param {string|null} emoji
 * @param {Object} opts emoji options, as given to `buildEmojiUrl`
 * @returns {string|undefined}
 */
export function resolveCalloutEmoji(type, emoji, opts) {
  return [emoji, CALLOUT_EMOJIS[type]].find(
    (name) =>
      name && !opts.emojiDenyList?.includes(name) && buildEmojiUrl(name, opts)
  );
}

function findClose(tokens, openIndex) {
  const level = tokens[openIndex].level;

  for (let i = openIndex + 1; i < tokens.length; i++) {
    if (tokens[i].type === "blockquote_close" && tokens[i].level === level) {
      return i;
    }
  }
}

function buildTitle(state, type, emoji) {
  const options = state.md.options.discourse;
  const text = new state.Token("text", "", 0);
  text.content = i18n(`post.callouts.${type}`);

  const name =
    options.features.emoji && resolveCalloutEmoji(type, emoji, options);

  if (!name) {
    return [text];
  }

  text.content = ` ${text.content}`;
  return [getEmojiTokenByName(name, state), text];
}

function applyCallouts(state) {
  const tokens = state.tokens;

  for (let i = 0; i < tokens.length; i++) {
    if (
      tokens[i].type !== "blockquote_open" ||
      tokens[i + 1].type !== "paragraph_open"
    ) {
      continue;
    }

    const inline = tokens[i + 2];
    const match = inline.content.match(MARKER_LINE);

    if (!match) {
      continue;
    }

    let closeIndex = findClose(tokens, i);
    const content = inline.content.slice(match[0].length);

    // like GitHub, a marker without any content stays a regular blockquote
    if (!content && closeIndex === i + 4) {
      continue;
    }

    if (content) {
      inline.content = content;
    } else {
      tokens.splice(i + 1, 3);
      closeIndex -= 3;
    }

    const type = match[1].toLowerCase();
    const emoji = match[2]?.toLowerCase();

    const open = tokens[i];
    open.type = "callout_open";
    open.tag = "div";
    open.attrs = [
      ["class", "callout"],
      ["data-callout-type", type],
    ];
    if (emoji) {
      open.attrPush(["data-callout-emoji", emoji]);
    }
    open.children = buildTitle(state, type, emoji);

    const close = tokens[closeIndex];
    close.type = "callout_close";
    close.tag = "div";
  }
}

function renderCalloutOpen(tokens, idx, options, env, slf) {
  const token = tokens[idx];
  const title = slf.renderInline(token.children, options, env);

  return `<div${slf.renderAttrs(token)}>\n<p class="callout__title">${title}</p>\n<div class="callout__content">\n`;
}

export function setup(helper) {
  helper.registerPlugin((md) => {
    md.core.ruler.after("block", "callouts", applyCallouts);
    md.renderer.rules.callout_open = renderCalloutOpen;
    md.renderer.rules.callout_close = () => "</div>\n</div>\n";
  });

  helper.allowList(["div.callout", "div.callout__content", "p.callout__title"]);
}
