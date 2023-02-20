// we need a custom renderer for code blocks cause we have a slightly non compliant
// format with special handling for text and so on
const TEXT_CODE_CLASSES = ["text", "pre", "plain"];

// Built manually from the highlight.js library using
// let aliases = {};
// hljs.listLanguages().forEach((lang) => {
//   aliases[lang] = hljs.getLanguage(lang).aliases;
// });
const HLJS_ALIASES = {
  bash: ["sh"],
  c: ["h"],
  cpp: ["cc", "c++", "h++", "hpp", "hh", "hxx", "cxx"],
  csharp: ["cs", "c#"],
  diff: ["patch"],
  go: ["golang"],
  graphql: ["gql"],
  ini: ["toml"],
  java: ["jsp"],
  javascript: ["js", "jsx", "mjs", "cjs"],
  kotlin: ["kt", "kts"],
  makefile: ["mk", "mak", "make"],
  markdown: ["md", "mkdown", "mkd"],
  objectivec: ["mm", "objc", "obj-c", "obj-c++", "objective-c++"],
  perl: ["pl", "pm"],
  plaintext: ["text", "txt"],
  python: ["py", "gyp", "ipython"],
  "python-repl": ["pycon"],
  ruby: ["rb", "gemspec", "podspec", "thor", "irb"],
  rust: ["rs"],
  shell: ["console", "shellsession"],
  typescript: ["ts", "tsx"],
  vbnet: ["vb"],
  xml: [
    "html",
    "xhtml",
    "rss",
    "atom",
    "xjb",
    "xsd",
    "xsl",
    "plist",
    "wsf",
    "svg",
  ],
  yaml: ["yml"],
};

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

  const acceptableCodeClasses =
    md.options.discourse.acceptableCodeClasses || [];

  if (TEXT_CODE_CLASSES.includes(tag)) {
    className = "lang-plaintext";
  } else if (acceptableCodeClasses.includes(tag)) {
    className = `lang-${tag}`;
  } else {
    className = "lang-plaintext";
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
    const languages = (siteSettings.highlighted_languages || "")
      .split("|")
      .filter(Boolean);
    const languageAliases = [];

    languages.forEach((lang) => {
      if (HLJS_ALIASES[lang]) {
        languageAliases.push(HLJS_ALIASES[lang]);
      }
    });

    opts.defaultCodeLang = siteSettings.default_code_lang;
    opts.acceptableCodeClasses = languages
      .concat(languageAliases.flat())
      .concat(["auto", "plaintext"]);
  });

  helper.allowList(["pre[data-code-*]"]);

  helper.allowList({
    custom(tag, name, value) {
      if (tag === "code" && name === "class") {
        const m = /^lang\-(.+)$/.exec(value);
        if (m) {
          return helper.getOptions().acceptableCodeClasses.includes(m[1]);
        }
      }
    },
  });

  helper.registerPlugin((md) => {
    md.renderer.rules.fence = (tokens, idx, options, env, slf) =>
      render(tokens, idx, options, env, slf, md);
  });
}
