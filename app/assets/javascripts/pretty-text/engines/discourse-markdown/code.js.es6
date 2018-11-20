// we need a custom renderer for code blocks cause we have a slightly non compliant
// format with special handling for text and so on

const TEXT_CODE_CLASSES = ["text", "pre", "plain"];

function render(tokens, idx, options, env, slf, md) {
  let token = tokens[idx],
    info = token.info ? md.utils.unescapeAll(token.info) : "",
    langName = md.options.discourse.defaultCodeLang,
    className,
    escapedContent = md.utils.escapeHtml(token.content);

  if (info) {
    // strip off any additional languages
    info = info.trim().split(/\s+/g)[0];
  }

  const acceptableCodeClasses = md.options.discourse.acceptableCodeClasses;
  if (
    acceptableCodeClasses &&
    info &&
    acceptableCodeClasses.indexOf(info) !== -1
  ) {
    langName = info;
  }

  className =
    TEXT_CODE_CLASSES.indexOf(info) !== -1
      ? "lang-nohighlight"
      : "lang-" + langName;

  return `<pre><code class="${className}">${escapedContent}</code></pre>\n`;
}

export function setup(helper) {
  helper.registerOptions((opts, siteSettings) => {
    opts.defaultCodeLang = siteSettings.default_code_lang;
    opts.acceptableCodeClasses = (siteSettings.highlighted_languages || "")
      .split("|")
      .concat(["auto", "nohighlight"]);
  });

  helper.whiteList({
    custom(tag, name, value) {
      if (tag === "code" && name === "class") {
        const m = /^lang\-(.+)$/.exec(value);
        if (m) {
          return helper.getOptions().acceptableCodeClasses.indexOf(m[1]) !== -1;
        }
      }
    }
  });

  helper.registerPlugin(md => {
    md.renderer.rules.fence = (tokens, idx, options, env, slf) =>
      render(tokens, idx, options, env, slf, md);
  });
}
