import { aiBadgeAllowList, renderAiBadge } from "../ai-badge.js";

// we need a custom renderer for code blocks cause we have a slightly non compliant
// format with special handling for text and so on
const TEXT_CODE_CLASSES = ["text", "pre", "plain"];

export function extractTokenInfo(info, md) {
  if (!info) {
    return;
  }

  const trimmed = info.trim();
  let [, language, options] = trimmed.match(/^(\S*)\s*(.*)/);
  // Leading whitespace distinguishes the AI flag from a language named "ai".
  if (/^\s+ai(?:[\s,]|$)/.test(info)) {
    language = "";
    options = trimmed;
  }

  // ensure the token has only valid chars
  // c++, strucuted-text and p91, are all valid
  if (!/^[\w+-]*$/i.test(language)) {
    return;
  }

  const ASCII_REGEX = /[^\x00-\x7F]/;
  const tag = md.utils.unescapeAll(language.replace(ASCII_REGEX, ""));
  const extractedData = { tag, options, attributes: {} };

  if (options) {
    md.utils
      .unescapeAll(options.replace(ASCII_REGEX, ""))
      .split(",")
      .forEach((potentialPair) => {
        const option = potentialPair.trim().split(/\s+/)[0];
        const [key, value] = option.split("=");

        if (option === "ai") {
          extractedData.attributes.ai = "true";
        } else if (key && key !== "ai" && value) {
          extractedData.attributes[key] = value;
        }
      });
  }

  return extractedData;
}

function render(tokens, idx, options, env, slf, md) {
  const token = tokens[idx];
  const escapedContent = md.utils.escapeHtml(token.content);
  const tokenInfo = extractTokenInfo(token.info, md);
  const tag = tokenInfo?.tag || md.options.discourse.defaultCodeLang;
  const attributes = tokenInfo?.attributes || {};
  if (tokenInfo?.tag) {
    attributes.language = tokenInfo.tag;
  } else {
    delete attributes.language;
  }

  let className;

  if (TEXT_CODE_CLASSES.includes(tag)) {
    className = "lang-plaintext";
  } else if (tag === "auto") {
    className = "lang-auto";
  } else {
    className = `lang-${md.utils.escapeHtml(tag)}`;
    attributes["wrap"] = tag;
  }

  const dataAttributes = Object.keys(attributes)
    .map((key) => {
      const value = md.utils.escapeHtml(attributes[key]);
      key = md.utils.escapeHtml(key);
      return `data-code-${key}="${value}"`;
    })
    .join(" ");

  const badge = attributes.ai === "true" ? renderAiBadge(md) : "";

  return `<pre${dataAttributes ? ` ${dataAttributes}` : ""}>${badge}<code${
    className ? ` class="${className}"` : ""
  }>${escapedContent}</code></pre>\n`;
}

export function setup(helper) {
  helper.registerOptions((opts, siteSettings) => {
    opts.defaultCodeLang = siteSettings.default_code_lang;
  });

  helper.allowList(["pre[data-code-*]", ...aiBadgeAllowList]);

  helper.allowList({
    custom(tag, name, value) {
      if (tag === "code" && name === "class") {
        // The value is still encoded here, so `&` has to be rejected: a
        // reference like `&#32;` is decoded into a class separator later.
        return /^lang-[^\s&]+$/.test(value);
      }
    },
  });

  helper.registerPlugin((md) => {
    md.renderer.rules.fence = (tokens, idx, options, env, slf) =>
      render(tokens, idx, options, env, slf, md);
  });
}
