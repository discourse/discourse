// we need a custom renderer for code blocks cause we have a slightly non compliant
// format with special handling for text and so on
const TEXT_CODE_CLASSES = ["text", "pre", "plain"];

function extractTokenInfo(info, md) {
  if (!info) {
    return;
  }

  info = info.trim();

  const matches = info.match(/(^\s*\S*)\s*(.*)/i);
  if (!matches) {
    return;
  }

  // ensure the token has only valid chars
  // c++, strucuted-text and p91, are all valid
  if (!/^[\w+-]*$/i.test(matches[1])) {
    return;
  }

  const ASCII_REGEX = /[^\x00-\x7F]/;
  const tag = md.utils.unescapeAll(matches[1].replace(ASCII_REGEX, ""));
  const extractedData = { tag, attributes: {} };

  if (matches[2]?.length) {
    md.utils
      .unescapeAll(matches[2].replace(ASCII_REGEX, ""))
      .split(",")
      .forEach((potentialPair) => {
        const [key, value] = potentialPair.trim().split(/\s+/g)[0].split("=");

        // invalid pairs would get caught here and not used, eg `foo=`
        if (key && value) {
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

  return `<pre${dataAttributes ? ` ${dataAttributes}` : ""}><code${
    className ? ` class="${className}"` : ""
  }>${escapedContent}</code></pre>\n`;
}

export function setup(helper) {
  helper.registerOptions((opts, siteSettings) => {
    opts.defaultCodeLang = siteSettings.default_code_lang;
  });

  helper.allowList(["pre[data-code-*]"]);

  helper.allowList({
    custom(tag, name, value) {
      if (tag === "code" && name === "class") {
        return /^lang\-.+$/.test(value);
      }
    },
  });

  helper.registerPlugin((md) => {
    md.renderer.rules.fence = (tokens, idx, options, env, slf) =>
      render(tokens, idx, options, env, slf, md);
  });
}
