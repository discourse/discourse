"use strict";

const bent = require("bent");
const getJSON = bent("json");
const { encode } = require("html-entities");
const cleanBaseURL = require("clean-base-url");
const path = require("path");
const fs = require("fs");

// via https://stackoverflow.com/a/6248722/165668
function generateUID() {
  let firstPart = (Math.random() * 46656) | 0; // eslint-disable-line no-bitwise
  let secondPart = (Math.random() * 46656) | 0; // eslint-disable-line no-bitwise
  firstPart = ("000" + firstPart.toString(36)).slice(-3);
  secondPart = ("000" + secondPart.toString(36)).slice(-3);
  return firstPart + secondPart;
}

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
    buffer.push(`<meta name="csrf-param" content="authenticity_token">`);
    buffer.push(`<meta name="csrf-token" content="${bootstrap.csrf_token}">`);
  }

  if (bootstrap.theme_id) {
    buffer.push(
      `<meta name="discourse_theme_id" content="${bootstrap.theme_id}">`
    );
  }

  if (bootstrap.theme_color) {
    buffer.push(`<meta name="theme-color" content="${bootstrap.theme_color}">`);
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
    if (s.class) {
      attrs.push(`class="${s.class}"`);
    }
    let link = `<link rel="stylesheet" type="text/css" href="${
      s.href
    }" ${attrs.join(" ")}>`;
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

function localeScript(buffer, bootstrap) {
  buffer.push(`<script src="${bootstrap.locale_script}"></script>`);
}

function beforeScriptLoad(buffer, bootstrap) {
  buffer.push(bootstrap.html.before_script_load);
  localeScript(buffer, bootstrap);
  (bootstrap.extra_locales || []).forEach((l) =>
    buffer.push(`<script src="${l}"></script>`)
  );
}

function body(buffer, bootstrap) {
  buffer.push(bootstrap.theme_html.header);
  buffer.push(bootstrap.html.header);
}

function bodyFooter(buffer, bootstrap, headers) {
  buffer.push(bootstrap.theme_html.body_tag);
  buffer.push(bootstrap.html.before_body_close);

  let v = generateUID();
  buffer.push(`
		<script async type="text/javascript" id="mini-profiler" src="/mini-profiler-resources/includes.js?v=${v}" data-css-url="/mini-profiler-resources/includes.css?v=${v}" data-version="${v}" data-path="/mini-profiler-resources/" data-horizontal-position="left" data-vertical-position="top" data-trivial="false" data-children="false" data-max-traces="20" data-controls="false" data-total-sql-count="false" data-authorized="true" data-toggle-shortcut="alt+p" data-start-hidden="false" data-collapse-results="true" data-html-container="body" data-hidden-custom-fields="x" data-ids="${headers["x-miniprofiler-ids"]}"></script>
	`);
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
  head,
  body,
  "hidden-login-form": hiddenLoginForm,
  preloaded,
  "body-footer": bodyFooter,
  "locale-script": localeScript,
};

function replaceIn(bootstrap, template, id, headers) {
  let buffer = [];
  BUILDERS[id](buffer, bootstrap, headers);
  let contents = buffer.filter((b) => b && b.length > 0).join("\n");

  return template.replace(`<bootstrap-content key="${id}">`, contents);
}

async function applyBootstrap(bootstrap, template, response) {
  // If our initial page added some preload data let's not lose that.
  let json = await response.json();
  if (json && json.preloaded) {
    bootstrap.preloaded = Object.assign(json.preloaded, bootstrap.preloaded);
  }

  Object.keys(BUILDERS).forEach((id) => {
    template = replaceIn(bootstrap, template, id, response);
  });
  return template;
}

function buildFromBootstrap(assetPath, proxy, baseURL, req, response) {
  // eslint-disable-next-line
  return new Promise((resolve, reject) => {
    fs.readFile(
      path.join(process.cwd(), "dist", assetPath),
      "utf8",
      (err, template) => {
        let url = `${proxy}${baseURL}bootstrap.json`;
        let queryLoc = req.url.indexOf("?");
        if (queryLoc !== -1) {
          url += req.url.substr(queryLoc);
        }

        getJSON(url, null, req.headers)
          .then((json) => {
            return applyBootstrap(json.bootstrap, template, response);
          })
          .then(resolve)
          .catch((e) => {
            reject(
              `Could not get ${proxy}${baseURL}bootstrap.json\n\n${e.toString()}`
            );
          });
      }
    );
  });
}

async function handleRequest(assetPath, proxy, baseURL, req, res) {
  if (assetPath.endsWith("tests/index.html")) {
    return;
  }

  if (assetPath.endsWith("index.html")) {
    try {
      // Avoid Ember CLI's proxy if doing a GET, since Discourse depends on some non-XHR
      // GET requests to work.
      if (req.method === "GET") {
        let url = `${proxy}${req.path}`;

        let queryLoc = req.url.indexOf("?");
        if (queryLoc !== -1) {
          url += req.url.substr(queryLoc);
        }

        req.headers["X-Discourse-Ember-CLI"] = "true";
        let get = bent("GET", [200, 301, 302, 303, 307, 308, 404, 403, 500]);
        let response = await get(url, null, req.headers);
        res.set(response.headers);
        res.set("content-type", "text/html");
        if (response.headers["x-discourse-bootstrap-required"] === "true") {
          req.headers["X-Discourse-Asset-Path"] = req.path;
          let html = await buildFromBootstrap(
            assetPath,
            proxy,
            baseURL,
            req,
            response
          );
          return res.send(html);
        }
        res.status(response.status);
        res.send(await response.text());
      }
    } catch (e) {
      res.send(`
                <html>
                  <h1>Discourse Build Error</h1>
                  <pre><code>${e.toString()}</code></pre>
                </html>
              `);
    }
  }
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

    if (!proxy) {
      // eslint-disable-next-line
      console.error(`
Discourse can't be run without a \`--proxy\` setting, because it needs a Rails application
to serve API requests. For example:

  yarn run ember serve --proxy "http://localhost:3000"\n`);
      throw "--proxy argument is required";
    }

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
          } catch (err) {}

          if (!isFile) {
            assetPath = "index.html";
          }
          await handleRequest(assetPath, proxy, baseURL, req, res);
        }
      } finally {
        if (!res.headersSent) {
          return next();
        }
      }
    });
  },

  shouldHandleRequest(req) {
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

    if (req.path.endsWith(".json")) {
      return false;
    }

    let baseURLRegexp = new RegExp(`^/`);
    return baseURLRegexp.test(req.path);
  },
};
