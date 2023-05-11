"use strict";

const express = require("express");
const { encode } = require("html-entities");
const cleanBaseURL = require("clean-base-url");
const path = require("path");
const fs = require("fs");
const fsPromises = fs.promises;
const { JSDOM } = require("jsdom");
const { shouldLoadPluginTestJs } = require("discourse-plugins");
const { Buffer } = require("node:buffer");
const { cwd, env } = require("node:process");

// via https://stackoverflow.com/a/6248722/165668
function generateUID() {
  let firstPart = (Math.random() * 46656) | 0; // eslint-disable-line no-bitwise
  let secondPart = (Math.random() * 46656) | 0; // eslint-disable-line no-bitwise
  firstPart = ("000" + firstPart.toString(36)).slice(-3);
  secondPart = ("000" + secondPart.toString(36)).slice(-3);
  return firstPart + secondPart;
}

function htmlTag(buffer, bootstrap) {
  let classList = "";
  if (bootstrap.html_classes) {
    classList = ` class="${bootstrap.html_classes}"`;
  }
  buffer.push(`<html lang="${bootstrap.html_lang}"${classList}>`);
}

function head(buffer, bootstrap, headers, baseURL) {
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

  if (bootstrap.authentication_data) {
    buffer.push(
      `<meta id="data-authentication" data-authentication-data="${encode(
        bootstrap.authentication_data
      )}">`
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

  if (bootstrap.preloaded.currentUser) {
    const user = JSON.parse(bootstrap.preloaded.currentUser);
    let { admin, staff } = user;

    if (staff) {
      buffer.push(`<script defer src="${baseURL}assets/admin.js"></script>`);
    }

    if (admin) {
      buffer.push(`<script defer src="${baseURL}assets/wizard.js"></script>`);
    }
  }

  bootstrap.plugin_js.forEach((src) =>
    buffer.push(`<script defer src="${src}"></script>`)
  );

  buffer.push(bootstrap.theme_html.translations);
  buffer.push(bootstrap.theme_html.js);
  buffer.push(bootstrap.theme_html.head_tag);
  buffer.push(bootstrap.html.before_head_close);
}

function localeScript(buffer, bootstrap) {
  buffer.push(`<script defer src="${bootstrap.locale_script}"></script>`);
}

function beforeScriptLoad(buffer, bootstrap) {
  buffer.push(bootstrap.html.before_script_load);
  localeScript(buffer, bootstrap);
  (bootstrap.extra_locales || []).forEach((l) =>
    buffer.push(`<script defer src="${l}"></script>`)
  );
}

function discoursePreloadStylesheets(buffer, bootstrap) {
  (bootstrap.stylesheets || []).forEach((s) => {
    let link = `<link rel="preload" as="style" href="${s.href}">`;
    buffer.push(link);
  });
}

function discourseStylesheets(buffer, bootstrap) {
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
    <script
      async
      type="text/javascript"
      id="mini-profiler"
      src="/mini-profiler-resources/includes.js?v=${v}"
      data-css-url="/mini-profiler-resources/includes.css?v=${v}"
      data-version="${v}"
      data-path="/mini-profiler-resources/"
      data-horizontal-position="right"
      data-vertical-position="top"
      data-trivial="false"
      data-children="false"
      data-max-traces="20"
      data-controls="false"
      data-total-sql-count="false"
      data-authorized="true"
      data-toggle-shortcut="alt+p"
      data-start-hidden="false"
      data-collapse-results="true"
      data-html-container="body"
      data-hidden-custom-fields="x"
      data-ids="${headers.get("x-miniprofiler-ids")}"
    ></script>
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
  "discourse-preload-stylesheets": discoursePreloadStylesheets,
  head,
  body,
  "discourse-stylesheets": discourseStylesheets,
  "hidden-login-form": hiddenLoginForm,
  preloaded,
  "body-footer": bodyFooter,
  "locale-script": localeScript,
};

function replaceIn(bootstrap, template, id, headers, baseURL) {
  let buffer = [];
  BUILDERS[id](buffer, bootstrap, headers, baseURL);
  let contents = buffer.filter((b) => b && b.length > 0).join("\n");

  return template.replace(`<bootstrap-content key="${id}">`, contents);
}

function extractPreloadJson(html) {
  const dom = new JSDOM(html);
  const dataElement = dom.window.document.querySelector("#data-preloaded");

  if (!dataElement || !dataElement.dataset) {
    return;
  }

  return dataElement.dataset.preloaded;
}

async function applyBootstrap(bootstrap, template, response, baseURL, preload) {
  bootstrap.preloaded = Object.assign(JSON.parse(preload), bootstrap.preloaded);

  Object.keys(BUILDERS).forEach((id) => {
    template = replaceIn(bootstrap, template, id, response.headers, baseURL);
  });
  return template;
}

async function buildFromBootstrap(proxy, baseURL, req, response, preload) {
  try {
    const template = await fsPromises.readFile(
      path.join(cwd(), "dist", "index.html"),
      "utf8"
    );

    let url = new URL(`${proxy}${baseURL}bootstrap.json`);
    url.searchParams.append("for_url", req.url);

    const forUrlSearchParams = new URL(req.url, "https://dummy-origin.invalid")
      .searchParams;

    const mobileView = forUrlSearchParams.get("mobile_view");
    if (mobileView) {
      url.searchParams.append("mobile_view", mobileView);
    }

    const reqUrlSafeMode = forUrlSearchParams.get("safe_mode");
    if (reqUrlSafeMode) {
      url.searchParams.append("safe_mode", reqUrlSafeMode);
    }

    const navigationMenu = forUrlSearchParams.get("navigation_menu");
    if (navigationMenu) {
      url.searchParams.append("navigation_menu", navigationMenu);
    }

    const reqUrlPreviewThemeId = forUrlSearchParams.get("preview_theme_id");
    if (reqUrlPreviewThemeId) {
      url.searchParams.append("preview_theme_id", reqUrlPreviewThemeId);
    }

    const { default: fetch } = await import("node-fetch");
    const res = await fetch(url, { headers: req.headers });
    const json = await res.json();

    return applyBootstrap(json.bootstrap, template, response, baseURL, preload);
  } catch (error) {
    throw new Error(
      `Could not get ${proxy}${baseURL}bootstrap.json\n\n${error}`
    );
  }
}

async function handleRequest(proxy, baseURL, req, res) {
  // x-forwarded-host is used in e.g. GitHub CodeSpaces
  let originalHost = req.headers["x-forwarded-host"] || req.headers.host;

  if (env["FORWARD_HOST"] === "true") {
    if (/^localhost(\:|$)/.test(originalHost)) {
      // Can't access default site in multisite via "localhost", redirect to 127.0.0.1
      res.redirect(
        307,
        `http://${originalHost.replace("localhost", "127.0.0.1")}${req.path}`
      );
      return;
    } else {
      req.headers.host = originalHost;
    }
  } else {
    req.headers.host = new URL(proxy).host;
  }

  if (req.headers["Origin"]) {
    req.headers["Origin"] = req.headers["Origin"]
      .replace(req.headers.host, originalHost)
      .replace(/^https/, "http");
  }

  if (req.headers["Referer"]) {
    req.headers["Referer"] = req.headers["Referer"]
      .replace(req.headers.host, originalHost)
      .replace(/^https/, "http");
  }

  let url = `${proxy}${req.path}`;
  const queryLoc = req.url.indexOf("?");
  if (queryLoc !== -1) {
    url += req.url.slice(queryLoc);
  }

  if (req.method === "GET") {
    req.headers["X-Discourse-Ember-CLI"] = "true";
  }

  const { default: fetch } = await import("node-fetch");
  const response = await fetch(url, {
    method: req.method,
    body: /GET|HEAD/.test(req.method) ? null : req.body,
    headers: req.headers,
    redirect: "manual",
  });

  response.headers.forEach((value, header) => {
    if (header === "set-cookie") {
      // Special handling to get array of multiple Set-Cookie header values
      // per https://github.com/node-fetch/node-fetch/issues/251#issuecomment-428143940
      res.set("set-cookie", response.headers.raw()["set-cookie"]);
    } else {
      res.set(header, value);
    }
  });
  res.set("content-encoding", null);

  const location = response.headers.get("location");
  if (location) {
    const newLocation = location.replace(proxy, `http://${originalHost}`);
    res.set("location", newLocation);
  }

  const csp = response.headers.get("content-security-policy");
  if (csp) {
    const emberCliAdditions = [
      `http://${originalHost}/assets/`,
      `http://${originalHost}/ember-cli-live-reload.js`,
      `http://${originalHost}/_lr/`,
    ].join(" ");

    const newCSP = csp
      .replaceAll(proxy, `http://${originalHost}`)
      .replaceAll("script-src ", `script-src ${emberCliAdditions} `);

    res.set("content-security-policy", newCSP);
  }

  const contentType = response.headers.get("content-type");
  const isHTML = contentType?.startsWith("text/html");

  res.status(response.status);

  if (isHTML) {
    const responseText = await response.text();
    const preloadJson = isHTML ? extractPreloadJson(responseText) : null;

    if (preloadJson) {
      const html = await buildFromBootstrap(
        proxy,
        baseURL,
        req,
        response,
        extractPreloadJson(responseText)
      );
      res.set("content-type", "text/html");
      res.send(html);
    } else {
      res.send(responseText);
    }
  } else {
    res.send(Buffer.from(await response.arrayBuffer()));
  }
}

module.exports = {
  name: require("./package").name,

  isDevelopingAddon() {
    return true;
  },

  contentFor(type, config) {
    if (shouldLoadPluginTestJs() && type === "test-plugin-js") {
      const scripts = [];

      const pluginInfos = this.app.project
        .findAddonByName("discourse-plugins")
        .pluginInfos();

      for (const {
        pluginName,
        directoryName,
        hasJs,
        hasAdminJs,
      } of pluginInfos) {
        if (hasJs) {
          scripts.push({
            src: `plugins/${directoryName}.js`,
            name: pluginName,
          });
        }

        if (fs.existsSync(`../plugins/${directoryName}_extras.js.erb`)) {
          scripts.push({
            src: `plugins/${directoryName}_extras.js`,
            name: pluginName,
          });
        }

        if (hasAdminJs) {
          scripts.push({
            src: `plugins/${directoryName}_admin.js`,
            name: pluginName,
          });
        }
      }

      return scripts
        .map(
          ({ src, name }) =>
            `<script src="${config.rootURL}assets/${src}" data-discourse-plugin="${name}"></script>`
        )
        .join("\n");
    } else if (shouldLoadPluginTestJs() && type === "test-plugin-tests-js") {
      return this.app.project
        .findAddonByName("discourse-plugins")
        .pluginInfos()
        .filter(({ hasTests }) => hasTests)
        .map(
          ({ directoryName, pluginName }) =>
            `<script src="${config.rootURL}assets/plugins/test/${directoryName}_tests.js" data-discourse-plugin="${pluginName}"></script>`
        )
        .join("\n");
    } else if (shouldLoadPluginTestJs() && type === "test-plugin-css") {
      return `<link rel="stylesheet" href="${config.rootURL}bootstrap/plugin-css-for-tests.css" data-discourse-plugin="_all" />`;
    }
  },

  serverMiddleware(config) {
    const app = config.app;
    let { proxy, rootURL, baseURL } = config.options;

    if (!proxy) {
      // eslint-disable-next-line no-console
      console.error(`
Discourse can't be run without a \`--proxy\` setting, because it needs a Rails application
to serve API requests. For example:

  yarn run ember serve --proxy "http://localhost:3000"\n`);
      throw "--proxy argument is required";
    }

    baseURL = rootURL === "" ? "/" : cleanBaseURL(rootURL || baseURL);

    const rawMiddleware = express.raw({ type: () => true, limit: "100mb" });
    const pathRestrictedRawMiddleware = (req, res, next) => {
      if (this.shouldHandleRequest(req, baseURL)) {
        return rawMiddleware(req, res, next);
      } else {
        return next();
      }
    };

    app.use(
      "/favicon.ico",
      express.static(
        path.join(
          __dirname,
          "../../../../../../public/images/discourse-logo-sketch-small.png"
        )
      )
    );

    app.use(pathRestrictedRawMiddleware, async (req, res, next) => {
      try {
        if (this.shouldHandleRequest(req, baseURL)) {
          await handleRequest(proxy, baseURL, req, res);
        } else {
          // Fixes issues when using e.g. "localhost" instead of loopback IP address
          req.headers.host = "127.0.0.1";
        }
      } catch (error) {
        res.send(`
          <html>
            <h1>Discourse Ember CLI Proxy Error</h1>
            <pre><code>${error.stack}</code></pre>
          </html>
        `);
      } finally {
        if (!res.headersSent) {
          return next();
        }
      }
    });
  },

  shouldHandleRequest(request, baseURL) {
    if (
      [
        `${baseURL}tests/index.html`,
        `${baseURL}ember-cli-live-reload.js`,
        `${baseURL}testem.js`,
        `${baseURL}assets/test-i18n.js`,
      ].includes(request.path)
    ) {
      return false;
    }

    if (request.path.startsWith("/_lr/")) {
      return false;
    }

    if (request.path.startsWith(`${baseURL}message-bus/`)) {
      return false;
    }

    return true;
  },
};
