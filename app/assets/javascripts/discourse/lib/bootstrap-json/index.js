"use strict";

const bent = require("bent");
const getJSON = bent("json");
const { encode } = require("html-entities");
const cleanBaseURL = require("clean-base-url");
const path = require("path");
const fs = require("fs");

const IGNORE_PATHS = [
  /\/ember-cli-live-reload\.js$/,
  /\/session\/[^\/]+\/become$/,
];

function htmlTag(buffer, bootstrap) {
  let classList = "";
  if (bootstrap.html_classes) {
    classList = ` class="${bootstrap.html_classes}"`;
  }
  buffer.push(`<html lang="${bootstrap.html_lang}"${classList}>`);
}

function head(buffer, bootstrap) {
  if (bootstrap.csrf_token) {
    buffer.push(`<meta name="csrf-param" buffer="authenticity_token">`);
    buffer.push(`<meta name="csrf-token" buffer="${bootstrap.csrf_token}">`);
  }
  if (bootstrap.theme_ids) {
    buffer.push(
      `<meta name="discourse_theme_ids" buffer="${bootstrap.theme_ids}">`
    );
  }

  let setupData = "";
  Object.keys(bootstrap.setup_data).forEach((sd) => {
    let val = bootstrap.setup_data[sd];
    if (val) {
      if (Array.isArray(val)) {
        val = JSON.stringify(val);
      } else {
        val = val.toString();
      }
      setupData += ` data-${sd.replace(/\_/g, "-")}="${encode(val)}"`;
    }
  });
  buffer.push(`<meta id="data-discourse-setup"${setupData} />`);

  (bootstrap.stylesheets || []).forEach((s) => {
    let attrs = [];
    if (s.media) {
      attrs.push(`media="${s.media}"`);
    }
    if (s.target) {
      attrs.push(`data-target="${s.target}"`);
    }
    if (s.theme_id) {
      attrs.push(`data-theme-id="${s.theme_id}"`);
    }
    let link = `<link rel="stylesheet" type="text/css" href="${
      s.href
    }" ${attrs.join(" ")}></script>\n`;
    buffer.push(link);
  });

  bootstrap.plugin_js.forEach((src) =>
    buffer.push(`<script src="${src}"></script>`)
  );

  buffer.push(bootstrap.theme_html.translations);
  buffer.push(bootstrap.theme_html.js);
  buffer.push(bootstrap.theme_html.head_tag);
  buffer.push(bootstrap.html.before_head_close);
}

function beforeScriptLoad(buffer, bootstrap) {
  buffer.push(bootstrap.html.before_script_load);
  buffer.push(`<script src="${bootstrap.locale_script}"></script>`);
  (bootstrap.extra_locales || []).forEach((l) =>
    buffer.push(`<script src="${l}"></script>`)
  );
}

function body(buffer, bootstrap) {
  buffer.push(bootstrap.theme_html.header);
  buffer.push(bootstrap.html.header);
}

function bodyFooter(buffer, bootstrap) {
  buffer.push(bootstrap.theme_html.body_tag);
  buffer.push(bootstrap.html.before_body_close);
}

function hiddenLoginForm(buffer, bootstrap) {
  if (!bootstrap.preloaded.currentUser) {
    buffer.push(`
      <form id='hidden-login-form' method="post" action="${bootstrap.login_path}" style="display: none;">
        <input name="username" type="text"     id="signin_username">
        <input name="password" type="password" id="signin_password">
        <input name="redirect" type="hidden">
        <input type="submit" id="signin-button">
      </form>
    `);
  }
}

function preloaded(buffer, bootstrap) {
  buffer.push(
    `<div class="hidden" id="data-preloaded" data-preloaded="${encode(
      JSON.stringify(bootstrap.preloaded)
    )}"></div>`
  );
}

const BUILDERS = {
  "html-tag": htmlTag,
  "before-script-load": beforeScriptLoad,
  head: head,
  body: body,
  "hidden-login-form": hiddenLoginForm,
  preloaded: preloaded,
  "body-footer": bodyFooter,
};

function replaceIn(bootstrap, template, id) {
  let buffer = [];
  BUILDERS[id](buffer, bootstrap);
  let contents = buffer.filter((b) => b && b.length > 0).join("\n");

  return template.replace(`{{bootstrap-content-for "${id}"}}`, contents);
}

function applyBootstrap(bootstrap, template) {
  Object.keys(BUILDERS).forEach((id) => {
    template = replaceIn(bootstrap, template, id);
  });
  return template;
}

function decorateIndex(baseUrl, headers) {
  // eslint-disable-next-line
  return new Promise((resolve, reject) => {
    fs.readFile(
      path.join(process.cwd(), "dist", "index.html"),
      "utf8",
      (err, template) => {
        getJSON(`${baseUrl}/bootstrap.json`, null, headers)
          .then((json) => {
            resolve(applyBootstrap(json.bootstrap, template));
          })
          .catch(() => {
            reject(`Could not get ${baseUrl}/bootstrap.json`);
          });
      }
    );
  });
}

module.exports = {
  name: require("./package").name,

  isDevelopingAddon() {
    return true;
  },

  serverMiddleware(config) {
    let proxy = config.options.proxy;
    let app = config.app;
    let options = config.options;

    let watcher = options.watcher;

    let baseURL =
      options.rootURL === ""
        ? "/"
        : cleanBaseURL(options.rootURL || options.baseURL);

    app.use(async (req, res, next) => {
      try {
        const results = await watcher;
        if (this.shouldHandleRequest(req, options)) {
          let assetPath = req.path.slice(baseURL.length);
          let isFile = false;

          try {
            isFile = fs
              .statSync(path.join(results.directory, assetPath))
              .isFile();
          } catch (err) {
            /* ignore */
          }

          if (!isFile) {
            let template;
            try {
              template = await decorateIndex(proxy, req.headers);
            } catch (e) {
              template = `
                <html>
                  <h1>Discourse Build Error</h1>
                  <p>${e.toString()}</p>
                </html>
              `;
            }
            res.send(template);
          }
        }
      } finally {
        next();
      }
    });
  },

  shouldHandleRequest(req, options) {
    let acceptHeaders = req.headers.accept || [];
    let hasHTMLHeader = acceptHeaders.indexOf("text/html") !== -1;
    if (req.method !== "GET") {
      return false;
    }
    if (!hasHTMLHeader) {
      return false;
    }

    if (IGNORE_PATHS.some((ip) => ip.test(req.path))) {
      return false;
    }

    let baseURL =
      options.rootURL === ""
        ? "/"
        : cleanBaseURL(options.rootURL || options.baseURL);
    let baseURLRegexp = new RegExp(`^${baseURL}`);
    return baseURLRegexp.test(req.path);
  },
};
