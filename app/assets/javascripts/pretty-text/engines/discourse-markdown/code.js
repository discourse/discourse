// we need a custom renderer for code blocks cause we have a slightly non compliant
// format with special handling for text and so on
const TEXT_CODE_CLASSES = ["text", "pre", "plain"];

function render(tokens, idx, options, env, slf, md) {
  const token = tokens[idx];
  let tokenInfoAttributes = {};
  const escapedContent = md.utils.escapeHtml(token.content);

  let tag;
  if (token.info) {
    let attributes;
    [tag, ...attributes] = token.info.trim().split(" ").filter(Boolean);

    (attributes || [])
      .join("")
      .split(",")
      .forEach((potentialPair) => {
        const [key, value] = potentialPair.trim().split("=");

        // invalid pairs would get caught here and not used, eg `foo=`
        if (key && value) {
          tokenInfoAttributes[key] = value;
        }
      });
  }

  tag = tag || md.options.discourse.defaultCodeLang;

  let className;
  if (/^[a-z]*$/i.test(tag)) {
    const acceptableCodeClasses =
      md.options.discourse.acceptableCodeClasses || [];

    if (TEXT_CODE_CLASSES.indexOf(tag) > -1) {
      className = "lang-nohighlight";
    } else if (acceptableCodeClasses.indexOf(tag) > -1) {
      className = `lang-${tag}`;
    } else {
      className = "lang-nohighlight";
      tokenInfoAttributes["wrap"] = tag;
    }
  }

  const dataAttributes = Object.keys(tokenInfoAttributes)
    .map((key) => {
      const value = md.utils.escapeHtml(tokenInfoAttributes[key]);
      key = md.utils.escapeHtml(key);
      return `data-${key}="${value}"`;
    })
    .join(" ");

  return `<pre${dataAttributes ? ` ${dataAttributes}` : ""}><code${
    className ? ` class="${className}"` : ""
  }>${escapedContent}</code></pre>`;
}

export function setup(helper) {
  helper.registerOptions((opts, siteSettings) => {
    opts.defaultCodeLang = siteSettings.default_code_lang;
    opts.acceptableCodeClasses = (siteSettings.highlighted_languages || "")
      .split("|")
      .filter(Boolean)
      .concat(["auto", "nohighlight"]);
  });

  helper.allowList({
    custom(tag, name, value) {
      if (tag === "code" && name === "class") {
        const m = /^lang\-(.+)$/.exec(value);
        if (m) {
          return helper.getOptions().acceptableCodeClasses.indexOf(m[1]) !== -1;
        }
      }
    },
  });

  helper.registerPlugin((md) => {
    md.renderer.rules.fence = (tokens, idx, options, env, slf) =>
      render(tokens, idx, options, env, slf, md);
  });
}
